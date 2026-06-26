#!/usr/bin/env python3
"""
Collects historical NESO embedded wind, solar, and metered wind data.

Background
----------
The UK electricity grid is split into two types of generation:

  - "Embedded" generation — smaller wind and solar farms connected directly to
    the local distribution network (the wires that serve homes and businesses).
    Because these generators bypass the main transmission system, their output
    is not directly metered by NESO; instead, NESO publishes an estimate.

  - "Metered" (transmission-connected) generation — large wind farms connected
    to the high-voltage national transmission grid. Their output is measured in
    real time by NESO's metering systems.

Both types affect electricity prices on the Agile Octopus tariff: more wind
generation generally lowers wholesale prices, which flows through to lower
half-hourly unit rates.

Data sources
------------
  - Embedded Wind and Solar Forecasts (archived CSV files, one per calendar year)
    https://www.neso.energy/data-portal/embedded-wind-and-solar-forecasts

  - Historic Day Ahead Wind Forecasts (live database, queryable via API)
    https://www.neso.energy/data-portal/day-ahead-wind-forecast
    Note: the issue references the "14 Days Ahead Wind Forecast" dataset, but
    that resource only carries the live 14-day rolling window.  The Historic
    Day Ahead Wind Forecasts resource in the same family contains the full
    settlement-period history and is used here instead.

Output
------
script/data/neso_generation_data.csv

One row per 30-minute settlement period, columns:
  settlement_date — date the settlement period falls on (YYYY-MM-DD)
  settlement_period — period number within the day; 1 = 00:00-00:30, 2 = 00:30-01:00, … 48 = 23:30-24:00 (1-50 on days when the clocks change)
  embedded_wind_forecast_mw — estimated embedded wind generation in megawatts
  embedded_solar_forecast_mw — estimated embedded solar generation in megawatts
  wind_forecast_mw — national metered wind day-ahead forecast in megawatts

Usage
-----
  python3 script/collect_neso_generation_data.py
"""

from __future__ import annotations  # Allows modern type-hint syntax (X | Y, dict[...]) on Python 3.7+

import collections.abc  # Provides the Iterator type annotation on iter_datastore_sql()
import csv              # Reads downloaded NESO CSV files and writes the merged output CSV
import http.client      # Provides IncompleteRead, raised when a download is cut off mid-stream
import io               # Wraps the download byte stream in a text reader for csv.DictReader
import json             # Decodes JSON responses from the NESO CKAN API
import logging          # Emits timestamped progress messages during long-running collection
import os               # Builds the output file path and creates the output directory
import re               # Extracts four-digit years from resource names to filter archive files
import time             # Pauses between successive requests to avoid overloading the server
import urllib.parse     # Encodes keyword arguments as URL query-string parameters
import urllib.request   # Makes HTTP requests to the NESO API and downloads forecast CSVs

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# The base URL for all NESO API calls. Every endpoint is appended to this.
API_BASE = "https://api.neso.energy"

# The "slug" (URL-friendly name) that identifies the Embedded Wind and Solar
# Forecasts dataset on the NESO data portal. The script uses this to ask the
# portal for a list of all downloadable files in that dataset, rather than
# hard-coding each file's URL — so it will still work when NESO adds new
# yearly archives in the future.
EMBEDDED_PACKAGE_SLUG = "embedded-wind-and-solar-forecasts"

# The unique ID of the specific database table that holds the Historic Day
# Ahead Wind Forecasts on the NESO portal. This ID never changes for an
# existing resource, so it is safe to hard-code here.
WIND_FORECAST_RESOURCE_ID = "7524ec65-f782-4258-aaf8-5b926c17b966"

# The start and end dates of the data to collect, both inclusive.
# Change these strings (keeping the YYYY-MM-DD format) to adjust the range.
DATE_FROM = "2020-01-01"
DATE_TO   = "2024-12-31"

# Where to write the finished CSV file.
# os.path.dirname(__file__) gives the directory that contains this script
# (i.e., the "script/" folder), so the output always ends up in "script/data/"
# regardless of which directory you run the script from.
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "data", "neso_generation_data.csv")

# Timeout in seconds for API calls returning JSON (metadata queries and SQL).
API_TIMEOUT_SECONDS = 60

# Timeout in seconds for CSV file downloads, which can be large.
DOWNLOAD_TIMEOUT_SECONDS = 120

# Seconds to pause between successive requests to avoid overloading the server.
REQUEST_DELAY_SECONDS = 0.2

# User-Agent header sent with every HTTP request to identify this script to
# NESO server administrators.
USER_AGENT = "agile-octopus-price-tracker/data-collection"

# CKAN API path for fetching dataset metadata, including the list of resources.
CKAN_PACKAGE_SHOW = "/api/3/action/package_show"

# CKAN API path for running SQL queries directly against the datastore.
CKAN_DATASTORE_SQL = "/api/3/action/datastore_search_sql"

# Regular expression matching a four-digit year in the 2000s surrounded by
# word boundaries, so "2020" in "Archive 2020" matches but "20200101" does not.
YEAR_PATTERN = re.compile(r"\b(20\d{2})\b")

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

# Set up progress messages so you can see what the script is doing while it
# runs. Each message is prefixed with the current time, making it easy to
# spot slow steps.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

# Build a reusable HTTP "opener" that automatically adds a User-Agent header
# to every request. The User-Agent string identifies this script to the NESO
# server — good practice so server administrators can see where traffic comes
# from. The opener also follows HTTP redirects automatically (which is needed
# because NESO's CSV download links redirect to cloud storage).
_opener = urllib.request.build_opener()
_opener.addheaders = [("User-Agent", USER_AGENT)]

# How many times to attempt a network operation before giving up. A full run
# streams several hundred-megabyte files and makes many API calls over several
# minutes, so a single transient blip should be retried rather than aborting
# the whole collection.
MAX_RETRIES = 3

# Seconds to wait before the first retry. This doubles after each failed
# attempt (so 2s, then 4s), giving a momentarily struggling server room to
# recover before the next try.
RETRY_BACKOFF_SECONDS = 2

# The kinds of error worth retrying: network/connection failures (urllib's
# URLError and the various ConnectionError types are all subclasses of OSError)
# and a download that was cut off part-way (http.client.IncompleteRead). Other
# errors — a malformed response, a bad URL, a parsing bug — are not retried,
# because trying again would not help.
RETRYABLE_ERRORS = (OSError, http.client.IncompleteRead)


def _with_retries(operation, description: str):
    """Run a network operation, retrying it if a transient error occurs.

    Parameters
    ----------
    operation   : a zero-argument function that performs the network work and
                  returns its result. It is called once per attempt.
    description  : a short label (e.g. a URL or file name) used in log messages
                  so you can see which operation is being retried.

    The operation is attempted up to MAX_RETRIES times. After a retryable
    failure the function waits a short, increasing delay and tries again. If
    every attempt fails, the final exception is re-raised so the caller can
    decide what to do (here, the run aborts rather than producing partial data).
    """
    delay = RETRY_BACKOFF_SECONDS
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            return operation()
        except RETRYABLE_ERRORS as exc:
            # On the final attempt there is nothing left to try — let the
            # exception propagate so the caller sees the failure.
            if attempt == MAX_RETRIES:
                raise
            log.warning(
                "    Attempt %d/%d failed for %s (%s); retrying in %ds...",
                attempt, MAX_RETRIES, description, exc, delay,
            )
            time.sleep(delay)
            delay *= 2  # Exponential backoff: 2s, then 4s, ...


def _api_get(path: str, **params) -> dict:
    """Call a NESO CKAN API endpoint and return the parsed JSON result.

    The NESO data portal is built on CKAN (a standard open-data platform).
    Every CKAN API response is a JSON object with a "success" flag and a
    "result" payload.  This helper:
      1. Builds the full URL by joining the base URL, the path, and any
         keyword arguments as query-string parameters.
      2. Opens the URL and reads the JSON response.
      3. Raises an error if the API reports failure.
      4. Returns only the inner "result" object so callers get straight to
         the data they need.

    Parameters
    ----------
    path   : the API endpoint path, e.g. "/api/3/action/package_show"
    params : keyword arguments that become URL query parameters, e.g., id="my-dataset" becomes "?id=my-dataset"
    """
    url = f"{API_BASE}{path}?{urllib.parse.urlencode(params)}"

    def fetch() -> dict:
        with _opener.open(url, timeout=API_TIMEOUT_SECONDS) as response:
            return json.load(response)

    payload = _with_retries(fetch, url)
    if not payload.get("success"):
        raise RuntimeError(f"NESO API error at {path}: {payload.get('error')}")
    return payload["result"]


def iter_datastore_sql(sql: str, batch: int = 5_000) -> collections.abc.Iterator[dict]:
    """Run a SQL query against the NESO datastore, yielding one row at a time.

    The NESO API limits how many rows it will return in a single response, so
    this function uses "pagination" — it repeatedly asks for the next chunk of
    rows (each chunk being `batch` rows) until there are no more left.  The
    caller sees a continuous stream of rows and does not need to worry about
    how many API calls were made behind the scenes.

    The SQL query passed in must NOT include LIMIT or OFFSET clauses, because
    this function appends them itself to control pagination.

    Parameters
    ----------
    sql   : a SQL SELECT statement targeting the NESO datastore
    batch : how many rows to request per API call (default 5,000)
    """
    offset = 0  # How many rows have already been fetched
    while True:
        # Append LIMIT and OFFSET to fetch the next page of results.
        paged_sql = f"{sql} LIMIT {batch} OFFSET {offset}"
        result = _api_get(CKAN_DATASTORE_SQL, sql=paged_sql)
        records = result["records"]

        # An empty page means we have fetched everything — stop the loop.
        if not records:
            break

        # This function is a "generator" — a Python feature that produces values
        # lazily, one at a time, rather than building the full result list in
        # memory before returning. "yield from" hands each row to the caller
        # (e.g., a for loop), then pauses here until the next row is requested.
        yield from records

        offset += len(records)

        # If we received fewer rows than the batch size, this was the last page.
        if len(records) < batch:
            break

        # Log progress and pause briefly to avoid hammering the API.
        log.info("    %d records fetched", offset)
        time.sleep(REQUEST_DELAY_SECONDS)


def download_csv(url: str) -> collections.abc.Iterator[dict]:
    """Download a CSV file from a URL, yielding its rows one dict at a time.

    Each row in the CSV becomes a dictionary whose keys are the column headers
    and whose values are the cell contents for that row.  For example, a row
    "2020-01-01,1,1057" with headers "date,period,mw" becomes:
    {"date": "2020-01-01", "period": "1", "mw": "1057"}

    The rows are *streamed*: the file is read and parsed incrementally rather
    than loaded into memory all at once.  This matters because the embedded
    archive files are very large (the 2024 archive is over 500 MB, since it
    records every forecast revision for every settlement period, not just one
    row per period).  Buffering a whole file would exhaust available memory.

    io.TextIOWrapper decodes the byte stream as UTF-8 on the fly and strips a
    leading BOM (byte order mark) if present — some of NESO's CSV files begin
    with an invisible BOM character that would otherwise corrupt the first
    column name.

    Because this is a generator, the network connection stays open until the
    caller has finished iterating over every row.

    Parameters
    ----------
    url : URL of the CSV file to download
    """
    with _opener.open(url, timeout=DOWNLOAD_TIMEOUT_SECONDS) as response:
        text_stream = io.TextIOWrapper(response, encoding="utf-8-sig")
        yield from csv.DictReader(text_stream)


# ---------------------------------------------------------------------------
# Embedded Wind and Solar Forecasts
# ---------------------------------------------------------------------------

def _parse_embedded_row(row: dict, date_from: str, date_to: str) -> tuple[tuple, dict] | None:
    """Extract the fields we need from one row of an embedded forecast CSV.

    Returns a (key, values) pair where key is (settlement_date, settlement_period)
    and values is a dict of the forecast fields.  Returns None if the row is
    malformed or falls outside the requested date range, so the caller can
    simply skip None results.

    The two archive formats differ slightly in column naming:
      - Older archives label the date column "SETTLEMENT_DATE"
      - The live resource uses "DATE_GMT" instead
    This function handles both.

    Parameters
    ----------
    row       : one row from an embedded forecast CSV, as a dict keyed by column name
    date_from : start of the collection window (YYYY-MM-DD, inclusive)
    date_to   : end of the collection window (YYYY-MM-DD, inclusive)
    """
    try:
        # Read the date, trying both column names. [:10] keeps only the
        # "YYYY-MM-DD" portion, discarding any time component.
        date_str = (row.get("SETTLEMENT_DATE") or row.get("DATE_GMT") or "")[:10]

        # Settlement period is stored as a string in the CSV, so convert to int.
        period = int(row.get("SETTLEMENT_PERIOD") or 0)

        # Reject rows where either field is missing or zero.
        if not date_str or not period:
            return None

        # Reject rows outside the requested date range.
        # String comparison works correctly here because the dates are in
        # YYYY-MM-DD format, which sorts lexicographically in date order.
        if not (date_from <= date_str <= date_to):
            return None

        return (date_str, period), {
            "embedded_wind_forecast_mw": row.get("EMBEDDED_WIND_FORECAST") or "",
            "embedded_solar_forecast_mw": row.get("EMBEDDED_SOLAR_FORECAST") or "",
        }
    except (ValueError, TypeError):
        # If any conversion fails (e.g., a non-numeric period), skip the row.
        return None


def _archive_year_in_range(name: str, date_from: str, date_to: str) -> bool:
    """Return True if a resource name contains at least one year within the date range.

    NESO names its archive files like "Embedded Solar and Wind Forecast Archive 2023".
    This function uses a regular expression to find all four-digit years starting
    with "20" in the name, then checks whether any of them fall within the
    collection window.

    Resources with no year in their name (such as the live rolling forecast,
    called simply "Embedded Solar and Wind Forecast") return False and are
    skipped — they contain only future forecast data, not the historical
    archives we need.

    Parameters
    ----------
    name      : NESO resource display name, e.g. "Embedded Solar and Wind Forecast Archive 2023"
    date_from : start of the collection window (YYYY-MM-DD)
    date_to   : end of the collection window (YYYY-MM-DD)
    """
    year_from = int(date_from[:4])  # e.g. "2020-01-01" → 2020
    year_to = int(date_to[:4])      # e.g. "2024-12-31" → 2024

    years = [int(y) for y in YEAR_PATTERN.findall(name)]

    return any(year_from <= y <= year_to for y in years)


def _download_and_parse_archive(url: str, date_from: str, date_to: str) -> dict[tuple, dict]:
    """Download one embedded archive CSV and return its in-range rows as a dict.

    The rows are parsed into a brand-new dictionary (rather than straight into
    the combined results) so that this whole operation is safe to retry: if a
    download fails part-way through and is attempted again, the retry starts
    from a clean slate instead of half-merging a truncated file into the
    results already gathered from other years.

    Returns a dict mapping (settlement_date, settlement_period) → forecast values
    for this one file.

    Parameters
    ----------
    url       : the download URL of the archive CSV
    date_from : start of the collection window (YYYY-MM-DD, inclusive)
    date_to   : end of the collection window (YYYY-MM-DD, inclusive)
    """
    file_data: dict[tuple, dict] = {}
    for row in download_csv(url):
        parsed = _parse_embedded_row(row, date_from, date_to)
        if parsed:
            key, values = parsed
            # If two rows share the same key, the later one (a more recent
            # forecast revision) overwrites the earlier one.
            file_data[key] = values
    return file_data


def collect_embedded_wind_solar(date_from: str, date_to: str) -> dict[tuple, dict]:
    """Download and parse the Embedded Wind and Solar Forecasts for the date range.

    The NESO portal stores this dataset as a collection of separate yearly
    CSV files (one per calendar year) plus one live rolling-forecast file.
    This function:
      1. Asks the portal for the full list of files in the dataset.
      2. Skips files that are outside the requested date range.
      3. Downloads and parses each relevant file.
      4. Stores the results in a dictionary keyed by (date, settlement_period)
         so they can be quickly looked up when writing the final CSV.

    Returns a dict mapping (settlement_date, settlement_period) → forecast values.

    Parameters
    ----------
    date_from : start of the collection window (YYYY-MM-DD, inclusive)
    date_to   : end of the collection window (YYYY-MM-DD, inclusive)
    """
    log.info("Discovering Embedded Wind and Solar Forecasts resources...")
    try:
        # "package_show" returns metadata for the whole dataset, including a
        # list of all the individual files (called "resources") it contains.
        result = _api_get(CKAN_PACKAGE_SHOW, id=EMBEDDED_PACKAGE_SLUG)
        resources = result["resources"]
    except Exception as exc:
        log.error("Could not list package resources: %s", exc)
        raise

    # Filter to CSV files only (the dataset also contains a documentation page).
    csv_resources = [r for r in resources if (r.get("format") or "").upper() == "CSV"]
    log.info("Found %d CSV resources", len(csv_resources))

    # This dict will accumulate one entry per (date, period) settlement slot.
    data: dict[tuple, dict] = {}

    for resource in csv_resources:
        name = resource.get("name") or resource.get("id", "?")
        url = resource.get("url") or ""
        if not url:
            continue

        # Skip the live forecast file and any yearly archives outside the range.
        if not _archive_year_in_range(name, date_from, date_to):
            log.info("  Skipping:    %s", name)
            continue

        log.info("  Downloading: %s", name)
        # Download and parse this archive, retrying transient network failures.
        # A failure that survives every retry is deliberately NOT caught here:
        # it propagates and aborts the run. A committed dataset that is silently
        # missing a whole year would be worse than a run that stops and says so.
        file_data = _with_retries(
            lambda: _download_and_parse_archive(url, date_from, date_to), name
        )
        before = len(data)
        data.update(file_data)
        log.info("    +%d rows  (total unique slots: %d)", len(data) - before, len(data))
        time.sleep(REQUEST_DELAY_SECONDS)

    return data


# ---------------------------------------------------------------------------
# Historic Day Ahead Wind Forecasts
# ---------------------------------------------------------------------------

def _parse_wind_row(row: dict) -> tuple[tuple, dict] | None:
    """Extract the fields we need from one row of the wind forecast database.

    The Historic Day Ahead Wind Forecasts table uses these column names:
      Date              — settlement date (YYYY-MM-DD)
      Settlement_period — period number within the day (1-48)
      Incentive_forecast — the day-ahead national wind forecast in MW
      Forecast_Timestamp — when this forecast was published (ISO datetime)

    The Forecast_Timestamp is used internally to decide which forecast to keep
    when the same settlement slot has been forecast multiple times (we keep the
    most recently published one).  It is not written to the output file.

    Returns a (key, values) pair, or None if the row cannot be parsed.

    Parameters
    ----------
    row : one row from the Historic Day Ahead Wind Forecasts table, as a dict
    """
    try:
        # [:10] trims any time component from the date string.
        date_str = (row.get("Date") or "")[:10]

        # The column name differs slightly between API versions, so try both.
        period = int(row.get("Settlement_period") or row.get("Settlement_Period") or 0)

        forecast_dt = row.get("Forecast_Timestamp") or row.get("ForecastDateTime") or ""

        if not date_str or not period:
            return None

        # Similarly, the forecast value column has two possible names.
        forecast_mw = row.get("Incentive_forecast") or row.get("Wind_Forecast") or ""

        return (date_str, period), {
            "wind_forecast_mw": forecast_mw,
            # Prefixed with "_" to indicate this field is for internal use only
            # and will not be written to the output CSV.
            "_forecast_dt": forecast_dt,
        }
    except (ValueError, TypeError):
        return None


def collect_wind_forecast(date_from: str, date_to: str) -> dict[tuple, dict]:
    """Fetch the Historic Day Ahead Wind Forecasts for the date range.

    Unlike the embedded forecast data (which is split into yearly CSV files),
    the wind forecast data lives in a single queryable database table on the
    NESO portal.  This function queries it directly using SQL, which lets us
    filter by date on the server side and avoid downloading data we don't need.

    Each settlement period may appear more than once in the database if NESO
    published multiple revised forecasts for it.  We keep only the most
    recently published forecast for each slot, as that represents NESO's best
    estimate at the time.

    Returns a dict mapping (settlement_date, settlement_period) → forecast values.

    Parameters
    ----------
    date_from : start of the collection window (YYYY-MM-DD, inclusive)
    date_to   : end of the collection window (YYYY-MM-DD, inclusive)
    """
    log.info(
        "Fetching Historic Day Ahead Wind Forecasts (%s to %s)...", date_from, date_to
    )

    # Build a SQL query that fetches only the rows in the date range, sorted
    # chronologically.  The LIMIT and OFFSET clauses are added later by
    # iter_datastore_sql to page through the results in chunks.
    sql = (
        f'SELECT * FROM "{WIND_FORECAST_RESOURCE_ID}" '
        f"WHERE \"Date\" >= '{date_from}' AND \"Date\" <= '{date_to}' "
        f'ORDER BY "Date", "Settlement_period"'
    )

    data: dict[tuple, dict] = {}
    total_rows = 0  # Count of all rows received (including duplicates per slot)

    for row in iter_datastore_sql(sql):
        parsed = _parse_wind_row(row)
        if not parsed:
            continue

        key, values = parsed
        existing = data.get(key)

        # If we have already seen a forecast for this slot, keep whichever was
        # published most recently — ISO datetime strings sort correctly as plain
        # strings, so ">" gives us the later timestamp.
        if existing is None or values["_forecast_dt"] > existing["_forecast_dt"]:
            data[key] = values

        total_rows += 1

    log.info("  %d unique slots from %d records", len(data), total_rows)
    return data


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

# The ordered list of column names that will appear in the output CSV.
# The order here determines the column order in the file.
FIELDNAMES = [
    "settlement_date",
    "settlement_period",
    "embedded_wind_forecast_mw",
    "embedded_solar_forecast_mw",
    "wind_forecast_mw",
]


def write_csv(embedded: dict[tuple, dict], wind: dict[tuple, dict], path: str) -> None:
    """Merge the two datasets and write the combined output to a CSV file.

    The two input dicts share the same key structure — (settlement_date,
    settlement_period) — so merging them is straightforward: take the union of
    all keys, then for each key look up values in both dicts.  If a slot exists
    in only one dataset, the columns from the other are left blank.

    Parameters
    ----------
    embedded : data from collect_embedded_wind_solar()
    wind     : data from collect_wind_forecast()
    path     : absolute or relative path to write the CSV file to
    """
    # Create the output directory if it does not already exist.
    # exist_ok=True means no error is raised if the directory is already there.
    os.makedirs(os.path.dirname(path), exist_ok=True)

    # dict.keys() returns a set-like view of the dictionary's keys. The "|"
    # operator computes the set union — every key present in either dict,
    # with no duplicates — before sorted() puts them in chronological order.
    all_keys = sorted(embedded.keys() | wind.keys())

    log.info("Writing %d settlement periods to %s...", len(all_keys), path)

    # Open the file for writing. newline="" is required by Python's csv module
    # to prevent it inserting extra blank lines on Windows.
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)

        # Write the header row (the column names).
        writer.writeheader()

        for date_str, period in all_keys:
            # Look up values for this slot in each dataset, defaulting to an
            # empty dict if the slot is absent from that dataset.
            emb = embedded.get((date_str, period), {})
            wnd = wind.get((date_str, period), {})

            # Write one row, leaving cells blank ("") where data is missing.
            writer.writerow({
                "settlement_date": date_str,
                "settlement_period": period,
                "embedded_wind_forecast_mw": emb.get("embedded_wind_forecast_mw", ""),
                "embedded_solar_forecast_mw": emb.get("embedded_solar_forecast_mw", ""),
                "wind_forecast_mw": wnd.get("wind_forecast_mw", ""),
            })

    log.info("Done.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    """Run the full data collection pipeline."""
    embedded = collect_embedded_wind_solar(DATE_FROM, DATE_TO)
    wind = collect_wind_forecast(DATE_FROM, DATE_TO)
    write_csv(embedded, wind, OUTPUT_PATH)


# This block ensures main() is only called when the script is run directly
# (e.g. "python3 collect_neso_generation_data.py"), not when it is imported
# as a module by another Python script.
if __name__ == "__main__":
    main()
