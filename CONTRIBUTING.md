# Contributing

## Datasets

The `script/data/` directory contains CSV datasets that the app depends on. These files are not committed to the repository because of their size, so you will need to generate them locally before building the app.

Both collection scripts use only the Python standard library — no additional packages are required. Python 3.7 or later is required (the scripts use `from __future__ import annotations`, so the modern type-hint syntax they contain works without a newer interpreter).

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
