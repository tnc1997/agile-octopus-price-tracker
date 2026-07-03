#!/usr/bin/env python3
"""
Exports the trained price-forecast model to ONNX and verifies inference parity.

Background
----------
`train_price_forecast_model.py` fits a regularized XGBoost regressor and writes
two intermediate, git-ignored artifacts to script/data/:

  - price_forecast_model.json    — the trained model in XGBoost's native format,
                                    sliced to the best boosting iteration, with
                                    the training contract embedded in its
                                    metadata attribute
  - price_forecast_model.joblib  — the fitted scikit-learn wrapper, pickled

Neither of those is what the Flutter app ships. The app runs inference through
onnxruntime, which consumes a portable ONNX graph. This script is the bridge: it
converts the trained model to ONNX and writes the result to the app's assets
directory, where it is tracked in version control and bundled with the app (see
issue #21). It is the ONNX file — not the .json or .joblib — that is the
committed artifact of the training pipeline.

Conversion
----------
The model is a gradient-boosted tree ensemble, which ONNX represents natively as
a single TreeEnsembleRegressor operator (in the ai.onnx.ml domain). onnxmltools
performs the translation: it reads the booster's trees — split features,
thresholds, default (missing) directions, and leaf values — plus the base score,
and emits the equivalent ONNX node. There is no approximation; the ONNX graph
evaluates the same arithmetic as XGBoost, so the two agree to within float32
rounding (see Verification).

Two details matter for the conversion to succeed and stay faithful:

  1. Best-iteration slice. train_price_forecast_model.py already trimmed the
     native .json to model.best_iteration + 1 trees, so loading it back gives a
     booster with exactly the trees the reported metrics were measured on. We
     convert that file (not the raw .joblib, whose wrapper hides surplus trees
     behind an iteration limit), so the exported graph serves precisely those
     trees to every consumer.

  2. Feature names. The model was fit from a pandas DataFrame, so its booster
     carries the real column names (time_of_day, is_weekend, ...). onnxmltools
     requires the generic f0, f1, ... naming, and the ONNX graph takes a single
     positional feature tensor regardless, so the names are cleared before
     conversion. The feature ORDER is unchanged and is what the ONNX input's
     columns mean; it is carried through from the model's embedded metadata and
     re-embedded in the ONNX file (see Output) so the Dart inference service can
     assemble its input tensor in the right order without guessing.

Verification
------------
The whole point of the export is that the ONNX graph predicts what the Python
model predicts, so the script proves it before writing anything. It builds a
batch of feature vectors, runs them through both the loaded scikit-learn model
and an onnxruntime session on the freshly converted graph, and compares the
outputs. The run aborts (non-zero exit, no file written) if the largest absolute
difference exceeds VERIFY_TOLERANCE.

The batch is grounded in the model itself rather than in guessed feature ranges:
every split threshold the trees actually use is read out of the booster, and the
batch is built to (a) sample each feature uniformly across the range its
thresholds span and (b) place points either side of every threshold.
That drives inputs down both branches of every split in the ensemble, so the
comparison exercises the full decision structure the conversion had to
reproduce — stronger coverage than random inputs over assumed ranges, and it
needs nothing but the model file. (Feeding a noninteger value for an ordinal
feature such as gsp is fine here: XGBoost and ONNX both branch on the same
numeric comparison, so it tests equivalence just as well as a realistic value.)

As a second, independent check, the native .json and the pickled .joblib are
both loaded and asserted to predict identically — confirming the two training
artifacts are the same model before either is trusted as the parity reference.

Output
------
../assets/price_forecast_model.onnx — the exported model, tracked in version
                                       control and bundled as a Flutter asset.
                                       The training contract (feature order, GSP
                                       encoding, peak window, generation columns,
                                       metrics, ...) is copied verbatim into the
                                       graph's metadata_props, so the ONNX file
                                       is self-describing exactly as the native
                                       .json was, with no sidecar to keep in sync.

Usage
-----
  python3 script/export_price_forecast_model.py

No arguments are required. Run train_price_forecast_model.py first so that the
input model artifacts exist. The export and verification together run in a second
or two.

Dependencies (see requirements.txt in the repository root):
  xgboost, scikit-learn, joblib, onnx, onnxmltools, onnxruntime, numpy
"""

from __future__ import annotations  # Allows modern type-hint syntax (list[...], dict[...]) on Python 3.7+

import json               # Reads the training contract embedded in the model and re-embeds it in the ONNX file
import logging            # Emits timestamped progress messages while converting and verifying
import os                 # Builds input/output paths relative to this script
import sys                # Exits with a non-zero code when an input is missing or verification fails

import joblib             # Loads the pickled scikit-learn wrapper for the independent artifact cross-check
import numpy as np        # Builds the verification batch and compares predictions
import onnx               # Stamps metadata onto, and serializes, the converted graph
import onnxmltools        # Converts the XGBoost booster to an ONNX TreeEnsembleRegressor
import onnxruntime as ort # Runs the converted graph to verify it matches the Python model
import xgboost as xgb     # Loads the trained native model for conversion
from onnxmltools.convert.common.data_types import FloatTensorType  # Declares the ONNX input tensor's type/shape

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# os.path.dirname(__file__) is the "script/" directory that contains this file,
# so the paths below resolve correctly regardless of the current directory.
SCRIPT_DIR = os.path.dirname(__file__)
DATA_DIR = os.path.join(SCRIPT_DIR, "data")

# Input model artifacts produced by train_price_forecast_model.py. Both live in
# the git-ignored data directory because they are intermediate build outputs.
MODEL_PATH = os.path.join(DATA_DIR, "price_forecast_model.json")
SKLEARN_MODEL_PATH = os.path.join(DATA_DIR, "price_forecast_model.joblib")

# Output ONNX model. Written to the app's assets directory (tracked in version
# control) rather than the git-ignored script/data directory used for the raw
# inputs, because this file is bundled as a Flutter asset. Mirrors where
# build_seasonal_average_lookup.py writes its lookup table.
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "..", "assets", "price_forecast_model.onnx")

# The name given to the ONNX graph's single input tensor. Its columns are the
# model's features, in the order recorded in the model's embedded metadata; the
# Dart inference service reads the same order back from the exported file.
INPUT_NAME = "input"

# Largest absolute difference (in p/kWh) tolerated between the Python model's
# predictions and the ONNX graph's over the verification batch. The conversion is
# exact bar float32 rounding, so the observed gap is a few 1e-5; this ceiling sits
# an order of magnitude above that (and below the 1e-4 precision Agile rates are
# quoted to) so it passes comfortably yet still trips on a real translation bug,
# which would shift predictions by whole pence, not micro-pence.
VERIFY_TOLERANCE = 1e-3

# Number of random feature vectors in the verification batch, on top of the
# threshold-straddling rows added for every split. A few thousand rows makes the
# comparison thorough while keeping the run near-instant.
VERIFY_SAMPLES = 5000

# Fixed seed so the verification batch — and therefore a rerun of this script —
# is reproducible.
VERIFY_SEED = 42

# Provenance stamped onto the exported graph's header, so a stray copy of the
# file can be traced back to what produced it.
PRODUCER_NAME = "export_price_forecast_model.py"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

def load_model() -> tuple[xgb.XGBRegressor, dict]:
    """Load the trained native model and its embedded training contract.

    Returns the fitted regressor (its booster already sliced to the best
    iteration by the training script) and the metadata dict read back from the
    model file. As an independent sanity check that the two training artifacts
    are the same model, the pickled scikit-learn wrapper is also loaded and
    asserted to predict identically to the native model on the verification
    batch — done later, once that batch exists.
    """
    model = xgb.XGBRegressor()
    model.load_model(MODEL_PATH)

    # The training contract (feature order, encodings, metrics, ...) that
    # train_price_forecast_model.py stored under the booster's "metadata"
    # attribute. It is a JSON string; decode it back to a dict.
    raw = model.get_booster().attr("metadata")
    if raw is None:
        log.error(
            "%s has no embedded metadata attribute — was it written by "
            "train_price_forecast_model.py?",
            MODEL_PATH,
        )
        sys.exit(1)
    metadata = json.loads(raw)

    log.info(
        "Loaded model from %s (%d trees, %d features)",
        MODEL_PATH,
        model.get_booster().num_boosted_rounds(),
        len(metadata["features"]),
    )
    return model, metadata


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

def convert(model: xgb.XGBRegressor, metadata: dict) -> onnx.ModelProto:
    """Convert the trained booster to an ONNX graph and embed the contract.

    Clears the booster's DataFrame-derived feature names (onnxmltools requires
    the generic f%d naming and the graph takes a single positional tensor
    anyway), converts to a TreeEnsembleRegressor, then copies the training
    metadata into the graph's metadata_props, so the exported file is
    self-describing.
    """
    features = metadata["features"]

    # onnxmltools rejects the real column names the model was trained with and
    # expects f0, f1, ...; clearing them lets it fall back to that convention.
    # The feature ORDER is untouched — it is what the input tensor's columns
    # mean, and it travels with the file via the embedded metadata below.
    booster = model.get_booster()
    booster.feature_names = None
    booster.feature_types = None

    # A single float input tensor of shape [batch, n_features]; None leaves the
    # batch dimension dynamic so the Dart side can score any number of slots.
    initial_types = [(INPUT_NAME, FloatTensorType([None, len(features)]))]
    # The whole model becomes one TreeEnsembleRegressor node in the ai.onnx.ml
    # domain, whose opset onnxmltools fixes at 1 — the only, and universally
    # supported, version of that operator. The graph emits no ai.onnx (default
    # domain) ops at all, so there is no target_opset worth pinning here: the
    # output is already at the most broadly compatible opset an onnxruntime
    # build (including the mobile one the app will bundle) can load.
    onnx_model = onnxmltools.convert_xgboost(
        model, initial_types=initial_types, name="price_forecast_model"
    )

    # Make the exported file traceable and self-describing.
    onnx_model.producer_name = PRODUCER_NAME
    onnx_model.doc_string = (
        "Agile Octopus price-forecast model (XGBoost regressor) exported to ONNX. "
        "Input 'input' is a [batch, {n}] float tensor whose columns are, in order: "
        "{cols}. Output is the forecast unit rate in p/kWh (inc. VAT). See the "
        "'training_metadata' entry in metadata_props for the full training contract."
    ).format(n=len(features), cols=", ".join(features))

    # Copy the whole training contract verbatim, plus the feature order on its
    # own key for a consumer that only needs that. metadata_props values must be
    # strings, so the contract is JSON-encoded exactly as it was in the native
    # model; a consumer reads it back with json.loads.
    props = {
        "training_metadata": json.dumps(metadata),
        "features": json.dumps(features),
    }
    for key, value in props.items():
        entry = onnx_model.metadata_props.add()
        entry.key = key
        entry.value = value

    # Fail loudly here rather than shipping a structurally invalid graph.
    onnx.checker.check_model(onnx_model)

    log.info("Converted model to ONNX (opset %s)", _opset_summary(onnx_model))
    return onnx_model


def _opset_summary(onnx_model: onnx.ModelProto) -> str:
    """Render the graph's imported opsets as 'domain:version' for logging."""
    return ", ".join(
        "{}:{}".format(imp.domain or "ai.onnx", imp.version)
        for imp in onnx_model.opset_import
    )


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

def build_verification_batch(model: xgb.XGBRegressor, metadata: dict) -> np.ndarray:
    """Build a feature batch that exercises every split in the ensemble.

    Reads the split thresholds the trees actually use out of the booster, then
    for each feature (a) samples uniformly across the range its thresholds span
    and (b) adds a pair of rows straddling every threshold. This drives inputs
    down both branches of every split, so the parity comparison covers the
    whole decision structure the conversion had to reproduce.

    Returns a float32 array of shape [rows, n_features], with the columns in the
    model's feature order.
    """
    features = metadata["features"]
    n_features = len(features)

    # trees_to_dataframe() lists every node; the non-leaf rows carry the feature
    # each split tests and its threshold. Group the thresholds by feature.
    nodes = model.get_booster().trees_to_dataframe()
    splits = nodes[nodes["Feature"] != "Leaf"]

    # Per-feature [low, high] sampling range and the sorted thresholds to
    # straddle. A feature the trees never split on gets a nominal [0, 1] range —
    # its value cannot affect the output, so any range verifies it.
    ranges: list[tuple[float, float]] = []
    thresholds_per_feature: list[np.ndarray] = []
    for name in features:
        feature_splits = splits.loc[splits["Feature"] == name, "Split"].to_numpy()
        if feature_splits.size:
            low = float(feature_splits.min())
            high = float(feature_splits.max())
            # Pad so the uniform sample reaches just beyond the extreme
            # thresholds (and stays non-degenerate when a feature has a single
            # split, i.e., low == high).
            pad = max(1.0, (high - low) * 0.05)
            ranges.append((low - pad, high + pad))
            thresholds_per_feature.append(np.unique(feature_splits))
        else:
            ranges.append((0.0, 1.0))
            thresholds_per_feature.append(np.empty(0, dtype=float))

    rng = np.random.default_rng(VERIFY_SEED)

    # (a) Random rows: each column uniform across its own threshold-spanned range.
    lows = np.array([low for low, _ in ranges])
    highs = np.array([high for _, high in ranges])
    random_rows = rng.uniform(lows, highs, size=(VERIFY_SAMPLES, n_features))

    # (b) Threshold-straddling rows: for each split threshold t of each feature,
    # two rows equal to a random baseline everywhere except that feature, which
    # is set just below and just above t. This guarantees each split is taken
    # both ways regardless of what the random rows happened to cover.
    straddle_rows: list[np.ndarray] = []
    for index, thresholds in enumerate(thresholds_per_feature):
        for threshold in thresholds:
            # A margin scaled to the threshold, with a floor for thresholds at 0.
            eps = max(abs(threshold) * 1e-4, 1e-4)
            baseline = rng.uniform(lows, highs)
            for value in (threshold - eps, threshold + eps):
                row = baseline.copy()
                row[index] = value
                straddle_rows.append(row)

    batch = np.vstack([random_rows, *straddle_rows]) if straddle_rows else random_rows
    return batch.astype(np.float32)


def verify(model: xgb.XGBRegressor, onnx_model: onnx.ModelProto, batch: np.ndarray) -> None:
    """Assert the ONNX graph matches the Python model over the batch.

    Runs the batch through both the scikit-learn model and an onnxruntime
    session on the converted graph, compares the outputs, logs the largest and
    mean absolute differences, and exits non-zero if the largest exceeds
    VERIFY_TOLERANCE (so no ONNX file is written when parity fails).
    """
    expected = model.predict(batch)

    session = ort.InferenceSession(
        onnx_model.SerializeToString(), providers=["CPUExecutionProvider"]
    )
    output_name = session.get_outputs()[0].name
    actual = session.run([output_name], {INPUT_NAME: batch})[0].ravel()

    differences = np.abs(expected - actual)
    max_difference = float(differences.max())
    mean_difference = float(differences.mean())

    log.info(
        "Verified %d rows: max |diff| = %.2e p/kWh, mean |diff| = %.2e p/kWh",
        len(batch),
        max_difference,
        mean_difference,
    )

    if max_difference > VERIFY_TOLERANCE:
        log.error(
            "ONNX predictions diverge from the Python model by up to %.2e p/kWh, "
            "over the %.0e tolerance — the export is unfaithful, not writing %s.",
            max_difference,
            VERIFY_TOLERANCE,
            OUTPUT_PATH,
        )
        sys.exit(1)


def cross_check_artifacts(model: xgb.XGBRegressor, batch: np.ndarray) -> None:
    """Confirm the native .json and pickled .joblib are the same model.

    An independent check on the training outputs before either is trusted: the
    scikit-learn wrapper is loaded from its pickle and asserted to predict
    identically to the native model this script converts. They should match
    exactly (bit-for-bit), since the training script sliced the native file to
    the same best iteration the wrapper predicts at.
    """
    if not os.path.exists(SKLEARN_MODEL_PATH):
        log.warning(
            "Skipping artifact cross-check: %s not found.", SKLEARN_MODEL_PATH
        )
        return

    wrapper = joblib.load(SKLEARN_MODEL_PATH)
    difference = float(np.abs(model.predict(batch) - wrapper.predict(batch)).max())
    if difference != 0.0:
        log.error(
            "Native model and pickled wrapper disagree by up to %.2e p/kWh — the "
            "training artifacts are out of sync; rerun train_price_forecast_model.py.",
            difference,
        )
        sys.exit(1)
    log.info("Cross-checked native .json against pickled .joblib: identical.")


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def save(onnx_model: onnx.ModelProto) -> None:
    """Write the verified ONNX graph to the assets directory."""
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    onnx.save_model(onnx_model, OUTPUT_PATH)
    log.info(
        "Saved ONNX model (%d bytes) to %s",
        os.path.getsize(OUTPUT_PATH),
        OUTPUT_PATH,
    )


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    """Run the full export pipeline: load, convert, verify, save."""
    if not os.path.exists(MODEL_PATH):
        log.error("Input model not found: %s", MODEL_PATH)
        log.error("Run train_price_forecast_model.py first.")
        sys.exit(1)

    model, metadata = load_model()

    # Build the batch once and reuse it for both the parity check and the
    # artifact cross-check, so the two are compared on identical inputs. This
    # must happen before convert(), which clears the booster's feature names —
    # the batch is assembled by reading split thresholds keyed on those names.
    batch = build_verification_batch(model, metadata)
    cross_check_artifacts(model, batch)

    onnx_model = convert(model, metadata)
    verify(model, onnx_model, batch)

    # Only reached when verification passed, so the written file is known good.
    save(onnx_model)

    log.info("Done.")


# Only run main() when executed directly, not when imported as a module.
if __name__ == "__main__":
    main()
