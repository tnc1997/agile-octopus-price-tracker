# Contributing

## Datasets

The `script/data/` directory contains CSV datasets that the app depends on. These files are not committed to the repository because of their size, so you will need to generate them locally before building the app.

Both collection scripts use only the Python standard library — no additional packages are required. Python 3.7 or later is required (the scripts use `from __future__ import annotations`, so the modern type-hint syntax they contain works without a newer interpreter).

The model scripts described under [Price forecast model](#price-forecast-model) below have heavier requirements: a modern Python (3.9 or later) and the third-party packages listed in `requirements.txt`.

### Prerequisites

Verify that Python 3.7 or later is available on your system:

```shell
python3 --version
```

### Agile Octopus price data

This script fetches every half-hour unit rate from 1 January 2020 to 31 December 2024 from the Octopus Energy API. It queries all known Agile product codes across all 14 Grid Supply Point (GSP) regions in Great Britain, averages the rates across regions for each half-hour slot, and writes the result to `script/data/agile_octopus_price_data.csv`.

```shell
python3 script/collect_agile_octopus_price_data.py
```

The script makes a large number of paginated API requests and may take several minutes to complete. Progress is logged to the terminal as it runs.

No authentication is required — the Octopus Energy API endpoint used here is publicly accessible.

### NESO generation data

This script fetches two datasets published by the National Energy System Operator (NESO) covering the same date range and merges them into a single file at `script/data/neso_generation_data.csv`:

- **Embedded wind and solar forecasts** — downloaded as yearly archive CSV files from the NESO data portal. These cover smaller generators connected to the local distribution network, whose output is estimated rather than directly metered.
- **Historic day-ahead wind forecasts** — queried via SQL against the NESO datastore API. These cover large wind farms connected to the national transmission grid.

```shell
python3 script/collect_neso_generation_data.py
```

Progress is logged to the terminal as it runs.

## Price forecast model

Octopus publishes Agile unit rates only about a day ahead, but the app shows a seven-day forecast. To fill the gap between the last published slot and the end of that window, the app predicts a plausible rate for each future half-hour slot from the conditions expected at the time — chiefly how much wind and solar generation the NESO forecasts. Earlier versions answered that question with a seasonal average lookup table (`assets/seasonal_average_lookup.json`, built by `script/build_seasonal_average_lookup.py`), which can only ever return the historical average for a bucket of conditions. The model described here replaces that lookup with a learned, continuous mapping from conditions to price, so it can interpolate between conditions and weigh features against one another rather than reading back a bucket average.

The model runs **on device**: the app performs inference locally through [onnxruntime](https://onnxruntime.ai/) rather than calling out to a server, so forecasting works offline and sends nothing about the user anywhere. That is why the shipped model is an [ONNX](https://onnx.ai/) file — a portable, framework-independent representation of the trained model that onnxruntime can load on every platform the app targets.

Producing that file is a two-step pipeline that builds on the datasets above: **training**, which fits the model, and **export to ONNX**, which converts the fitted model into the portable format and verifies the conversion is faithful. Run the two [dataset collection scripts](#datasets) first — the pipeline reads the CSVs they produce — then run the two steps below in order. Only the final `assets/price_forecast_model.onnx` is committed to the repository (it is bundled with the app as a Flutter asset); the intermediate model files that training produces are treated like the datasets and left in the git-ignored `script/data/` directory.

### Dependencies

Unlike the collection scripts, which use only the Python standard library, these two steps depend on third-party packages (XGBoost, scikit-learn, and the ONNX toolchain — see `requirements.txt` for the full list and the reasons some versions are pinned). Install them into a [virtual environment](https://docs.python.org/3/library/venv.html) — a self-contained Python installation that keeps these packages isolated from the rest of your system:

```shell
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

This creates the environment in a `.venv/` directory (git-ignored) and installs the dependencies into it. The commands below invoke Python from inside that environment (`.venv/bin/python`), so the packages are available without affecting any other Python you have installed. You only need to create and populate the environment once; reuse it for later runs.

### Training

```shell
.venv/bin/python script/train_price_forecast_model.py
```

This script fits a regularized [XGBoost](https://xgboost.readthedocs.io/) regressor — a model made of many small decision trees, each correcting the errors of the ones before it. It joins the price and generation datasets on their shared settlement date and period (aligning the UTC price timestamps to the UK local clock time the NESO data uses), derives the model's input features for each slot (the half-hour of the day, whether it is a weekend, whether it falls in the evening peak, the month, the GSP region, and the three wind and solar generation forecasts), and trains the model to predict `value_inc_vat`, the unit rate in pence per kWh including VAT.

The data is split chronologically — the earliest slots train the model, a middle slice tunes it, and the most recent slots are held back to test it — so the reported accuracy reflects how well the model forecasts slots it has never seen, rather than being flattered by peeking at neighboring future slots. Training stops early once accuracy on the tuning slice stops improving. The script logs its progress, the relative importance of each feature, and the final accuracy metrics (RMSE, MAE, and R²) measured on the held-out test slice; it runs in well under a minute.

It writes the trained model to `script/data/` in two forms: `price_forecast_model.json`, XGBoost's own portable format (with the training details — feature order, encodings, and metrics — embedded in it), and `price_forecast_model.joblib`, the fitted scikit-learn object pickled to disk. Both describe the same model; the export step uses the first and cross-checks it against the second.

### Export to ONNX

```shell
.venv/bin/python script/export_price_forecast_model.py
```

This script converts the trained model into the ONNX format the app loads. Crucially, it **verifies that the conversion is faithful before writing anything**: it feeds a large batch of inputs — constructed to exercise every decision branch in the trees — through both the original Python model and the freshly converted ONNX graph, and compares the two sets of predictions. If they ever diverge by more than a negligible rounding margin, the script reports the discrepancy and aborts without writing a file, so a broken conversion can never silently ship. As a further safeguard it also confirms the model's two on-disk forms (the `.json` and the `.joblib`) agree with each other. It copies the training details into the ONNX file's metadata as well, so the exported model is self-describing, and the app can read back the exact feature order it must supply.

Only when every check passes does it write `assets/price_forecast_model.onnx`. Because that file is the committed artifact the app ships, **re-run this step whenever you retrain the model** so the asset stays in sync with the model it was produced from. The export and its verification should be complete in a second or two.
