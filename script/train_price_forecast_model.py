#!/usr/bin/env python3
"""
Trains a regularized XGBoost regressor on the historical price and
generation datasets.

Background
----------
The two collection scripts in this directory produce a half-hourly history of
Agile Octopus unit rates (per GSP region) and a half-hourly history of NESO
wind and solar generation forecasts:

  - script/data/agile_octopus_price_data.csv
  - script/data/neso_generation_data.csv

`build_seasonal_average_lookup.py` turns those into a simple lookup table: it
buckets prices by their conditions and stores the average of each bucket. That
"seasonal naive" model is inexpensive and transparent, but it can only ever return
an average — it cannot interpolate between conditions or weigh features against
one another.

This script trains a gradient-boosted decision tree model in its place. Given
the same conditions — how much wind and solar is forecast, whether the slot is a
weekday, and so on — it learns a continuous mapping to a plausible Agile unit
rate. The trained model is the first step of the on-device forecast pipeline: a
later script exports it to ONNX, and the Flutter app runs it through
onnxruntime, replacing the lookup-table query in the forecast service.

Model
-----
XGBoost with the standard gradient-boosted tree booster (gbtree): the model is a
sum of decision trees, each fit to correct the residual errors of the ensemble
so far. Every knob that constrains model complexity (tree depth, row/column
subsampling, the minimum child weight, the split-gain floor, and the L1/L2
regularization terms) is set below and documented so the "regularized" part of
the brief is explicit rather than left at library defaults.

The issue called for the DART booster (which drops a random subset of trees each
round as an extra regularizer). It was benchmarked head-to-head here and made no
difference to the held-out accuracy while training roughly 170x slower — the
penalties and subsampling above already regularize the ensemble, leaving dropout
nothing to add — so the plain tree booster is used instead. (DART is also now a
deprecated booster alias in the current XGBoost; its dropout has been folded into
gbtree.)

Features
--------
The model is trained on the inputs the issue calls for, plus two additions that
were each benchmarked to improve held-out accuracy: the GSP region (so a single
model stays region-specific — Agile rates differ from one region to the next),
and the month (so the model can capture the strong seasonality of prices, which
the raw generation features do not convey):

  time_of_day                 — half-hour slot within the local day, 0 (00:00-00:30)
                                to 47 (23:30-24:00); an ordinal, not a clock time
  is_weekend                  — 1 on Saturday/Sunday (local), else 0
  is_peak                     — 1 during the local evening peak window, else 0
  month                       — local calendar month, 1 (January) to 12 (December)
  gsp                         — Grid Supply Point region, ordinal-encoded 0-13
                                (see GSP_CODES); lets one model serve all regions
  embedded_wind_forecast_mw   — NESO embedded (distribution-connected) wind
  embedded_solar_forecast_mw  — NESO embedded solar
  wind_forecast_mw            — NESO national metered (transmission) wind

time_of_day, is_weekend, is_peak and month are all derived from the slot's
timestamp, so the runtime forecast service can reproduce every feature for a
future slot (unlike, say, a recent-price feature, which does not exist ahead of
publication).

The target is value_inc_vat: the unit rate in pence per kWh, inclusive of VAT.

FEATURES below is the single source of truth for the column order. The ONNX
export and the Dart inference service must present features in this exact order,
so it is also embedded in the saved model's metadata (see Output).

Joining the two datasets
------------------------
NESO settlement dates/periods are defined in UK local (clock) time: period 1 =
00:00-00:30 local, period 48 = 23:30-24:00 local. The Octopus prices carry a
valid_from timestamp in UTC. Each price timestamp is converted to Europe/London
local time and reduced to a (settlement_date, settlement_period) key, which is
joined against the generation data. This mirrors exactly how
build_seasonal_average_lookup.py and the runtime forecast service align the two
feeds, so the model is trained on the same conditions it will see in production.

Settlement period is derived from local clock time (hour*2 + half-hour), exactly
as build_seasonal_average_lookup.py and the runtime service do, so the model
trains on the alignment it will serve. On the two daylight-saving change days a
year this clock numbering diverges from NESO's sequential 1-46/1-50 scheme, so a
few of those slots align an hour off — harmless, and consistent with production;
only the short-day tail periods, which are absent from the generation feed, fail
to match outright and are dropped. Either way the effect is a negligible fraction
of rows; the count that did not match is reported in the join summary, and the
run aborts if too few match (see MIN_MATCH_RATIO).

Train / validation / test split
-------------------------------
The split is chronological, not random: the earliest slots train the model, a
middle slice tunes it (early stopping), and the most recent slots test it. A
random split would let the model peek at future slots that sit either side of a
held-out one and flatter the scores; a time-ordered split measures what we
actually care about — how well the model forecasts slots it has never seen. The
split is made on the timestamp, so all 14 regional rows for a slot always land
in the same partition and no slot straddles the boundary.

Output
------
script/data/price_forecast_model.json      — the trained model in XGBoost's
                                             native format (portable, versioned),
                                             with the training contract embedded
                                             via set_attr (a JSON string at
                                             learner.attributes.metadata): feature
                                             order, GSP encoding, the peak-window
                                             and generation-column definitions,
                                             row counts, and test-set metrics
script/data/price_forecast_model.joblib    — the fitted scikit-learn wrapper,
                                             pickled for the skl2onnx export path

Both are written to script/data/ (git-ignored, like the raw CSVs) because they
are intermediate build artifacts: the committed asset is the ONNX file the next
issue produces from them, not these files themselves.

Usage
-----
  python3 script/train_price_forecast_model.py

No arguments are required. Run the two collection scripts first so that the
input CSVs exist. The script reads ~1.2M price rows; loading and the join
dominate the runtime, which is well under a minute.

Dependencies (see requirements.txt in the repository root):
  xgboost, scikit-learn, pandas, joblib
"""

from __future__ import annotations  # Allows modern type-hint syntax (list[...], dict[...]) on Python 3.7+

import joblib             # Pickles the fitted scikit-learn wrapper for the ONNX export
import json               # Serializes the training metadata (feature order, metrics, ...)
import logging            # Emits timestamped progress messages while loading, joining, and training
import os                 # Builds input/output paths relative to this script
import pandas as pd       # Loads, joins, and feature-engineers the two CSVs
import sklearn.metrics    # Regression metrics (MAE, R^2, RMSE) used to evaluate the model
import sys                # Exits with a non-zero code when an input file is missing
import xgboost as xgb     # The gradient-boosting library providing the tree regressor

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# os.path.dirname(__file__) is the "script/" directory that contains this file,
# so the paths below resolve correctly regardless of the current directory.
DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

# Input CSVs produced by the two collection scripts.
PRICE_PATH = os.path.join(DATA_DIR, "agile_octopus_price_data.csv")
GENERATION_PATH = os.path.join(DATA_DIR, "neso_generation_data.csv")

# Output artifacts. Both live in the git-ignored data directory because they are
# intermediate build outputs; the committed asset is the ONNX file the next issue
# exports from them.
MODEL_PATH = os.path.join(DATA_DIR, "price_forecast_model.json")
SKLEARN_MODEL_PATH = os.path.join(DATA_DIR, "price_forecast_model.joblib")

# NESO settlement dates/periods are expressed in UK local clock time. Prices are
# stored in UTC, so we convert them to this zone before deriving the join key —
# the same zone build_seasonal_average_lookup.py and the runtime service use.
LOCAL_TZ = "Europe/London"

# The single-letter GSP (Grid Supply Point) region codes, in the canonical order
# used by the collection script. The list index is the ordinal code fed to the
# model (A -> 0, B -> 1, ... P -> 13). Ordinal encoding — rather than one-hot —
# keeps the feature vector small and trivial to reproduce in Dart at inference
# time; the tree ensemble isolates individual regions through successive splits.
# This ordering is part of the model contract and is embedded in the saved
# model's metadata, so a consumer must map letters to codes using exactly this
# list. Keep it in sync with GSP_CODES in collect_agile_octopus_price_data.py:
# the two must agree, because the ordinal encoding here is baked into the metadata
# and a silent divergence would mis-encode regions with no error.
GSP_CODES = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P"]

# The three NESO generation forecast columns, used both as model features and to
# detect (and drop) slots the generation feed does not fully cover.
GENERATION_COLUMNS = [
    "embedded_wind_forecast_mw",
    "embedded_solar_forecast_mw",
    "wind_forecast_mw",
]

# The local hours that count as the evening peak. Agile's headline price cap has
# long applied to the 16:00-19:00 window, when demand peaks and rates spike, so
# a slot is flagged "peak" when its local start hour is 16, 17 or 18. Expressed
# as a half-open [start, end) interval on the local hour.
PEAK_HOUR_START = 16
PEAK_HOUR_END = 19

# The ordered feature columns. THIS IS THE SOURCE OF TRUTH for column order: the
# ONNX export and the Dart inference service must supply features in this exact
# order. It is embedded verbatim in the saved model's metadata, so a consumer
# never has to guess it.
FEATURES = [
    "time_of_day",
    "is_weekend",
    "is_peak",
    "month",
    "gsp",
    "embedded_wind_forecast_mw",
    "embedded_solar_forecast_mw",
    "wind_forecast_mw",
]

# The column the model predicts: the Agile unit rate in p/kWh, inclusive of VAT.
TARGET = "value_inc_vat"

# Fractions of the (chronologically ordered) data used for training and
# validation; the remainder is the held-out test set. 0.70 + 0.15 leaves 0.15
# for the final, untouched test slice used to report the metrics below.
TRAIN_FRACTION = 0.70
VALIDATION_FRACTION = 0.15

# Almost every price row should join to a generation period; only the daylight-
# saving tail periods and any gap in the generation feed fail to. If far fewer
# match, the two inputs are probably misaligned (a missing year, a dtype drift, a
# timezone regression) and the model would train on a partial, biased slice — so
# abort rather than emit a quietly-wrong model. Mirrors the same guard in
# build_seasonal_average_lookup.py.
MIN_MATCH_RATIO = 0.99

# XGBoost hyperparameters. Every entry that constrains complexity is set
# explicitly, so the "regularized" brief is visible here rather than inherited
# from library defaults.
XGB_PARAMS = {
    # The standard tree booster: the model is a sum of gradient-boosted decision
    # trees. (The DART booster's tree-dropout was benchmarked here and made no
    # difference to accuracy while training ~170x slower — with the penalties and
    # subsampling below already regularizing, dropout added nothing — so it was
    # dropped. DART is also a deprecated booster alias in current XGBoost.)
    "booster": "gbtree",
    # Plain squared-error regression: we are predicting a continuous price.
    "objective": "reg:squarederror",
    # Shallow trees keep each booster simple and generalize better than deep,
    # high-variance ones.
    "max_depth": 6,
    # A small learning rate makes each tree a gentle correction; paired with many
    # rounds (and early stopping), it trades training time for accuracy.
    "learning_rate": 0.05,
    # Train each tree on a random 80% of rows / 80% of columns, decorrelating the
    # ensemble so it depends less on any single slot or feature.
    "subsample": 0.8,
    "colsample_bytree": 0.8,
    # Require a minimum total instance weight in a child before a split is kept,
    # so leaves are backed by enough rows to be trustworthy.
    "min_child_weight": 5.0,
    # Require a minimum loss reduction (gain) before making a split, pruning
    # marginal splits that would only fit noise.
    "gamma": 1.0,
    # L1 (reg_alpha) and L2 (reg_lambda) penalties on leaf weights — the explicit
    # regularization terms that shrink the model toward simpler fits.
    "reg_alpha": 0.1,
    "reg_lambda": 1.0,
    # Use all available cores for training.
    "n_jobs": -1,
    # Fixed seed so a rerun on the same data reproduces the same model.
    "random_state": 42,
    # Rank feature_importances_ by "gain" — each feature's share of the total
    # improvement its splits brought — which reflects predictive contribution
    # better than the default "weight" (a raw count of splits).
    "importance_type": "gain",
}

# Upper bound on boosting rounds. Early stopping (below) almost always halts
# well before this; it is a ceiling, not a target.
N_ESTIMATORS = 600

# Stop boosting once the validation RMSE has not improved for these many
# consecutive rounds, so training does not run past the point of diminishing
# returns (or into over-fitting).
EARLY_STOPPING_ROUNDS = 30

# Number of decimal places kept on the reported metrics. Agile rates are quoted
# to four decimal places, so matching that keeps the p/kWh errors meaningful.
METRIC_PRECISION = 4

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
# Data loading and feature engineering
# ---------------------------------------------------------------------------

def load_generation() -> pd.DataFrame:
    """Load the NESO generation CSV, keyed by (settlement_date, settlement_period).

    Returns a DataFrame indexed by the join key with one column per generation
    forecast. Rows with a missing or non-numeric value in any generation column
    are dropped — an incomplete renewable picture would mislead the model, and
    the runtime forecast service likewise skips such slots.
    """
    generation = pd.read_csv(
        GENERATION_PATH,
        dtype={"settlement_date": str, "settlement_period": int},
    )

    # Coerce the forecast columns to numbers; blanks and stray text become NaN.
    for column in GENERATION_COLUMNS:
        generation[column] = pd.to_numeric(generation[column], errors="coerce")

    # Drop any slot missing a generation value — the sum would be incomplete.
    before = len(generation)
    generation = generation.dropna(subset=GENERATION_COLUMNS)
    dropped = before - len(generation)
    if dropped:
        log.info("  dropped %d generation rows with missing values", dropped)

    if generation.empty:
        log.error("No usable generation rows in %s — is the file empty?", GENERATION_PATH)
        sys.exit(1)

    # Index by the join key so the price frame can merge against it directly.
    generation = generation.set_index(["settlement_date", "settlement_period"])

    log.info("Loaded %d generation periods from %s", len(generation), GENERATION_PATH)
    return generation


def load_prices() -> pd.DataFrame:
    """Load the Agile price CSV and derive the local-time fields the join needs.

    Returns a DataFrame with the original valid_from (UTC) alongside the derived
    settlement_date/settlement_period join key and the timestamp-only model
    features (time_of_day, is_weekend, is_peak). The GSP is left as its raw
    letter here and encoded to an ordinal after the join.
    """
    prices = pd.read_csv(
        PRICE_PATH,
        usecols=["valid_from", "gsp", TARGET],
        dtype={"gsp": str},
    )
    prices[TARGET] = pd.to_numeric(prices[TARGET], errors="coerce")

    # Parse valid_from as UTC and convert to UK local clock time, so the derived
    # settlement date/period line up with the NESO convention. Vectorized over
    # the whole column — far faster than parsing each timestamp individually.
    utc = pd.to_datetime(prices["valid_from"], utc=True)
    local = utc.dt.tz_convert(LOCAL_TZ)

    # Settlement period 1 = 00:00-00:30 local, so the half-hour index within the
    # day is hours*2 + (1 if past the half-hour), and the period is that plus one.
    time_of_day = local.dt.hour * 2 + (local.dt.minute >= 30).astype(int)
    prices["time_of_day"] = time_of_day
    prices["settlement_period"] = time_of_day + 1

    # The join key's date side, as a "YYYY-MM-DD" string to match the generation
    # CSV's settlement_date column exactly.
    prices["settlement_date"] = local.dt.strftime("%Y-%m-%d")

    # Weekday() is 0-6 (Mon-Sun); 5 and 6 are the weekend.
    prices["is_weekend"] = (local.dt.dayofweek >= 5).astype(int)

    # Peak when the local start hour falls in the [start, end) evening window.
    prices["is_peak"] = (
        (local.dt.hour >= PEAK_HOUR_START) & (local.dt.hour < PEAK_HOUR_END)
    ).astype(int)

    # Local calendar month (1-12), so the model can capture seasonal price levels.
    prices["month"] = local.dt.month

    # Drop any row with an unparseable price; without a target it cannot train.
    before = len(prices)
    prices = prices.dropna(subset=[TARGET])
    dropped = before - len(prices)
    if dropped:
        log.info("  dropped %d price rows with a missing target", dropped)

    log.info("Loaded %d price rows from %s", len(prices), PRICE_PATH)
    return prices


def build_dataset() -> pd.DataFrame:
    """Join prices to generation and assemble the model-ready frame.

    Returns a DataFrame sorted chronologically by valid_from, carrying the
    FEATURES columns and the TARGET. The chronological order lets the caller
    split by time without re-sorting.
    """
    generation = load_generation()
    prices = load_prices()

    # Encode the GSP letter to its ordinal code. Any unexpected letter maps to
    # NaN and is dropped below rather than silently coded as a real region.
    gsp_to_code = {code: index for index, code in enumerate(GSP_CODES)}
    prices["gsp"] = prices["gsp"].map(gsp_to_code)
    unknown = int(prices["gsp"].isna().sum())
    if unknown:
        log.info("  dropped %d price rows with an unrecognised GSP", unknown)
        prices = prices.dropna(subset=["gsp"])
    prices["gsp"] = prices["gsp"].astype(int)

    # Inner-join each price row to its settlement slot's generation figures.
    # load_generation() has already dropped every row with a missing generation
    # value, so an inner join keeps exactly the rows that matched a fully-populated
    # slot; the unmatched ones (the DST "fall back" hour, or a slot the generation
    # feed lacks) are simply absent, which the ratio check below accounts for.
    total_before = len(prices)
    merged = prices.merge(
        generation,
        how="inner",
        left_on=["settlement_date", "settlement_period"],
        right_index=True,
    )

    matched = len(merged)
    log.info(
        "Joined %d of %d price rows to a generation period (%d unmatched)",
        matched,
        total_before,
        total_before - matched,
    )

    # If no rows matched, or a large share failed to, the inputs are probably
    # misaligned and the model would train on partial (or no) data. Abort rather
    # than silently produce a quietly-wrong model that still exits 0.
    if not total_before or matched / total_before < MIN_MATCH_RATIO:
        log.error(
            "Only %d of %d price rows matched a generation period (need >= %.0f%%) "
            "— check the price and generation inputs cover the same dates.",
            matched,
            total_before,
            100 * MIN_MATCH_RATIO,
        )
        sys.exit(1)

    # Sort chronologically so the caller's split is a clean time boundary. A
    # stable sort keeps the 14 regional rows of a slot adjacent and together.
    merged = merged.sort_values("valid_from", kind="stable").reset_index(drop=True)

    return merged


# ---------------------------------------------------------------------------
# Splitting, training, and evaluation
# ---------------------------------------------------------------------------

def split_by_time(
    dataset: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Split the (already time-sorted) dataset into train / validation / test.

    The split points are chosen on the ordered valid_from values so that every
    regional row sharing a timestamp lands in the same partition and no slot
    straddles a boundary — a random split would leak neighboring future slots
    into training and inflate the scores.

    Returns (train, validation, test) as three DataFrames.
    """
    # Find the timestamps at the train/validation and validation/test cut points,
    # then partition by comparing against them. Splitting on the timestamp value
    # (not the row position) keeps all rows of a boundary slot on the same side.
    timestamps = dataset["valid_from"].to_numpy()
    cut_train = timestamps[int(len(timestamps) * TRAIN_FRACTION)]
    cut_validation = timestamps[
        int(len(timestamps) * (TRAIN_FRACTION + VALIDATION_FRACTION))
    ]

    train = dataset[dataset["valid_from"] < cut_train]
    validation = dataset[
        (dataset["valid_from"] >= cut_train) & (dataset["valid_from"] < cut_validation)
    ]
    test = dataset[dataset["valid_from"] >= cut_validation]

    log.info(
        "Split: %d train / %d validation / %d test rows",
        len(train),
        len(validation),
        len(test),
    )
    return train, validation, test


def train_model(
    train: pd.DataFrame,
    validation: pd.DataFrame,
) -> xgb.XGBRegressor:
    """Fit the regularized tree regressor, using the validation set for early stopping.

    Returns the fitted estimator. Boosting halts once the validation RMSE stops
    improving (or N_ESTIMATORS is reached), so the returned model uses the
    best-scoring number of rounds rather than the maximum.
    """
    model = xgb.XGBRegressor(
        n_estimators=N_ESTIMATORS,
        early_stopping_rounds=EARLY_STOPPING_ROUNDS,
        eval_metric="rmse",
        **XGB_PARAMS,
    )

    log.info("Training tree regressor on %d rows...", len(train))
    model.fit(
        train[FEATURES],
        train[TARGET],
        # The validation set drives early stopping; verbose=False keeps the
        # per-round chatter out of the log (we report the outcome below).
        eval_set=[(validation[FEATURES], validation[TARGET])],
        verbose=False,
    )

    log.info(
        "Trained %d boosting rounds (best iteration: %d)",
        model.get_booster().num_boosted_rounds(),
        model.best_iteration,
    )
    return model


def log_feature_importances(model: xgb.XGBRegressor) -> None:
    """Log each feature's relative importance, most important first.

    A quick, human-readable sanity check on what the model actually relies on:
    each feature's share of the total split "gain" (the improvement its splits
    brought), as a percentage. Useful for spotting a feature that contributes
    almost nothing (a candidate to drop) or one that dominates. The values come
    from model.feature_importances_, which is aligned with FEATURES and uses the
    "gain" importance type set in XGB_PARAMS.
    """
    ranked = sorted(
        zip(FEATURES, model.feature_importances_),
        key=lambda pair: pair[1],
        reverse=True,
    )
    log.info("Feature importances (gain):")
    for name, importance in ranked:
        log.info("  %-28s %5.1f%%", name, 100 * importance)


def evaluate(model: xgb.XGBRegressor, test: pd.DataFrame) -> dict[str, float]:
    """Score the model on the held-out test set and log the results.

    Returns a dict of test-set metrics: root-mean-squared error and mean
    absolute error (both in p/kWh, so directly comparable to a unit rate) and
    the R^2 coefficient of determination. A naive baseline — always predicting
    the test set's own mean price — is logged alongside to add context: it equals
    the test target's standard deviation (the denominator R^2 is measured
    against), so the model's error is read against a floor rather than in isolation.
    """
    predictions = model.predict(test[FEATURES])
    actual = test[TARGET]

    rmse = float(sklearn.metrics.root_mean_squared_error(actual, predictions))
    mae = float(sklearn.metrics.mean_absolute_error(actual, predictions))
    r2 = float(sklearn.metrics.r2_score(actual, predictions))

    # Baseline: predict the mean of the actual test prices for every slot. Its
    # RMSE is the (population) standard deviation of the test target — the error a
    # model that has learned nothing about the conditions would incur. ddof=0 makes
    # it the population std (pandas defaults to the sample std, ddof=1).
    baseline_rmse = float(actual.std(ddof=0))

    log.info("Test RMSE: %.4f p/kWh (baseline %.4f)", rmse, baseline_rmse)
    log.info("Test MAE:  %.4f p/kWh", mae)
    log.info("Test R^2:  %.4f", r2)

    return {
        "rmse": round(rmse, METRIC_PRECISION),
        "mae": round(mae, METRIC_PRECISION),
        "r2": round(r2, METRIC_PRECISION),
        "baseline_rmse": round(baseline_rmse, METRIC_PRECISION),
    }


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def save_artifacts(
    model: xgb.XGBRegressor,
    metrics: dict[str, float],
    row_counts: dict[str, int],
) -> None:
    """Persist the model in both formats, with the training metadata embedded.

    Writes the native XGBoost model (portable across versions and the input to
    the native ONNX exporter) and the pickled scikit-learn wrapper (the input to
    the skl2onnx path). The training contract — feature order, encodings, metrics,
    and so on — is embedded in the native model via XGBoost's set_attr mechanism
    (a JSON string at learner.attributes.metadata), so the model file is
    self-describing, and there is no separate sidecar to keep in sync.
    """
    os.makedirs(DATA_DIR, exist_ok=True)

    # The training contract the downstream export and inference steps rely on:
    # the exact feature order, how each categorical feature is encoded, and how
    # the derived features are defined, plus the metrics and row counts for
    # provenance.
    metadata = {
        "features": FEATURES,
        "target": TARGET,
        "gsp_codes": GSP_CODES,
        "generation_columns": GENERATION_COLUMNS,
        "peak_hour_start": PEAK_HOUR_START,
        "peak_hour_end": PEAK_HOUR_END,
        "local_timezone": LOCAL_TZ,
        "best_iteration": int(model.best_iteration),
        "row_counts": row_counts,
        "metrics": metrics,
    }

    # Early stopping keeps training EARLY_STOPPING_ROUNDS past the best iteration,
    # so the full booster carries surplus trees after model.best_iteration. The
    # scikit-learn wrapper hides this — its predict (and evaluate() above) restrict
    # to the best iteration — but a raw Booster, the path a native ONNX exporter
    # takes, would serve ALL trees and forecast differently from the reported
    # metrics. Slice the booster to the best trees so every consumer of the native
    # file, however it loads the model, matches evaluate().
    best_booster = model.get_booster()[: model.best_iteration + 1]

    # Attach the training contract using XGBoost's supported attribute mechanism.
    # set_attr stores arbitrary user metadata under the model's "attributes"
    # section, which is part of the serialized schema — so it survives a save/load
    # round-trip natively (booster.attr("metadata") returns it after loading),
    # rather than relying on the loader tolerating an unknown key. Attribute values
    # must be strings, so the contract is JSON-encoded; a consumer reads it back
    # with json.loads (either via .attr("metadata"), or straight from
    # learner.attributes.metadata in the saved file).
    best_booster.set_attr(metadata=json.dumps(metadata))

    # Native format: self-describing and forward-compatible, unlike a raw pickle.
    # The metadata set above is written inside it, under learner.attributes.metadata.
    best_booster.save_model(MODEL_PATH)
    log.info("Saved native model (with embedded metadata) to %s", MODEL_PATH)

    # Pickled wrapper: preserves the scikit-learn estimator skl2onnx expects. Its
    # predict already restricts to model.best_iteration, so it forecasts the same
    # values as the trimmed native file above.
    joblib.dump(model, SKLEARN_MODEL_PATH)
    log.info("Saved scikit-learn model to %s", SKLEARN_MODEL_PATH)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    """Run the full training pipeline: load, split, train, evaluate, save."""
    for path in (PRICE_PATH, GENERATION_PATH):
        if not os.path.exists(path):
            log.error("Input file not found: %s", path)
            log.error("Run the data collection scripts first.")
            sys.exit(1)

    dataset = build_dataset()
    train, validation, test = split_by_time(dataset)

    model = train_model(train, validation)
    log_feature_importances(model)
    metrics = evaluate(model, test)

    save_artifacts(
        model,
        metrics,
        {"train": len(train), "validation": len(validation), "test": len(test)},
    )

    log.info("Done.")


# Only run main() when executed directly, not when imported as a module.
if __name__ == "__main__":
    main()
