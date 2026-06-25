#!/usr/bin/env python3
"""
Collects historical Agile Octopus price data and saves it to a CSV file.

Background
----------
Agile Octopus is a time-of-use electricity tariff offered by Octopus Energy.
Unlike a fixed-rate tariff, it charges a different unit rate for each half-hour
slot of the day. Rates are set the evening before based on wholesale electricity
market prices, meaning they are lower when supply is plentiful (e.g., on a sunny
or windy day) and higher during periods of peak demand.

Rates also vary by Grid Supply Point (GSP) region — the 14 geographic areas
into which Great Britain's electricity distribution network is divided. Because
each region has a different mix of local generation and demand, the rates charged
to customers in, say, London differ from those in Northern Scotland.

Over its lifetime the tariff has been issued under several product codes as its
terms have changed. The full price history is therefore spread across multiple
products, all of which are queried here and merged into a single dataset.

This script fetches every half-hour rate from 1 January 2020 to 31 December 2024
(inclusive) across all 14 GSP regions and writes one row per region per slot to
script/data/agile_octopus_price_data.csv. Storing per-region prices allows the
downstream lookup table generation script to produce a region-specific forecast
for the end-user's Grid Supply Point.

Data sources
------------
  - Octopus Energy REST API — standard unit rates endpoint
    https://api.octopus.energy/v1/products/{product_code}/electricity-tariffs/{tariff_code}/standard-unit-rates/

Output
------
script/data/agile_octopus_price_data.csv

One row per GSP region per half-hour slot, columns:
  valid_from    — start of the half-hour slot (ISO 8601 UTC datetime, e.g., 2024-01-01T00:00:00Z)
  valid_to      — end of the half-hour slot (ISO 8601 UTC datetime, e.g., 2024-01-01T00:30:00Z)
  gsp           — single-letter Grid Supply Point region code (e.g., C for London)
  value_inc_vat — unit rate including VAT (at 5%), in pence per kilowatt-hour (p/kWh)

Usage
-----
  python3 script/collect_agile_octopus_price_data.py

No arguments are required. The script may take several minutes to run as it
makes a large number of requests to the Octopus Energy API.
"""

from __future__ import annotations  # Allows modern type-hint syntax (list[...], dict[...]) on Python 3.7+

import csv             # Writes the per-region half-hourly rates to the output CSV file
import datetime        # datetime.datetime for date parsing; datetime.timezone for UTC
import json            # Decodes JSON responses from the Octopus Energy API
import logging         # Emits timestamped progress messages during long-running collection
import os              # Creates the data/ output directory before writing the CSV
import sys             # Exits with a non-zero code on failure
import time            # Pauses between paginated API requests to avoid overloading the server
import urllib.error    # Catches URLError/HTTPError to handle network failures and 404s
import urllib.parse    # Encodes period_from, period_to, and page_size as API query parameters
import urllib.request  # Makes HTTP GET requests to the Octopus Energy API

# Base URL for the Octopus Energy REST API.
BASE_URL = "https://api.octopus.energy"

# Number of rates to request per API call. 1500 is the practical maximum and
# reduces the total number of round trips needed to fetch the full history.
PAGE_SIZE = 1500

# The Agile Octopus tariff has been sold under several product codes since its
# launch in February 2018. Octopus introduces a new product code each time the
# tariff terms change, so the full price history is spread across all of them.
# They are listed here in chronological order. Each is queried independently
# and 404 responses are silently skipped, so this list is safe to extend as
# new products are released.
AGILE_PRODUCTS = [
    "AGILE-18-02-21",
    "AGILE-22-07-22",
    "AGILE-22-08-31",
    "AGILE-FLEX-22-11-25",
    "AGILE-23-12-06",
    "AGILE-24-04-03",
    "AGILE-24-10-01",
]

# The single-letter suffix that identifies each of the 14 Grid Supply Point
# (GSP) regions in Great Britain. Rates are stored separately per region so
# that the downstream lookup table can be tailored to the end-user's GSP.
GSP_CODES = [
    "A",  # Eastern England
    "B",  # East Midlands
    "C",  # London
    "D",  # Merseyside and Northern Wales
    "E",  # West Midlands
    "F",  # North Eastern England
    "G",  # North Western England
    "H",  # Southern England
    "J",  # South Eastern England
    "K",  # Southern Wales
    "L",  # South Western England
    "M",  # Yorkshire
    "N",  # Southern Scotland
    "P",  # Northern Scotland
]

# Human-readable name for each GSP code, used in progress output.
GSP_REGIONS = {
    "A": "Eastern England",
    "B": "East Midlands",
    "C": "London",
    "D": "Merseyside and Northern Wales",
    "E": "West Midlands",
    "F": "North Eastern England",
    "G": "North Western England",
    "H": "Southern England",
    "J": "South Eastern England",
    "K": "Southern Wales",
    "L": "South Western England",
    "M": "Yorkshire",
    "N": "Southern Scotland",
    "P": "Northern Scotland",
}

# The start and end of the date range to collect, both inclusive.
DATE_FROM = "2020-01-01"
DATE_TO   = "2025-01-01"

# strptime/strftime format string for the YYYY-MM-DD dates used by the API.
DATE_FORMAT = "%Y-%m-%d"

# Prefix for all Octopus electricity tariff codes. "E" = electricity,
# "1R" = single register (a standard, non-Economy-7 meter).
TARIFF_PREFIX = "E-1R"

# HTTP status code returned when a product or tariff code does not exist.
HTTP_NOT_FOUND = 404

# Seconds to pause between paginated API requests to avoid overloading the server.
REQUEST_DELAY_SECONDS = 0.2

# Path to the output CSV file. os.path.dirname(__file__) gives the directory
# that contains this script (i.e., the "script/" folder), so the output always
# ends up in "script/data/" regardless of which directory you run the script from.
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "data", "agile_octopus_price_data.csv")

# Ordered column names for the output CSV.
OUTPUT_FIELDNAMES = ["valid_from", "valid_to", "gsp", "value_inc_vat"]

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


def fetch_unit_rates(
    product_code: str,
    tariff_code: str,
    period_from: datetime.datetime,
    period_to: datetime.datetime,
) -> list[dict]:
    """Fetch all unit rates for a single tariff within a date range.

    The API returns results in pages. This function follows the "next" link in
    each response until all pages have been retrieved, then returns the combined
    list of rates. Returns an empty list if the tariff does not exist (HTTP 404),
    which happens when a product code was not active in the requested date range.

    Parameters
    ----------
    product_code : Octopus product code, e.g. "AGILE-24-10-01"
    tariff_code  : full tariff code including the GSP suffix, e.g. "E-1R-AGILE-24-10-01-C"
    period_from  : start of the date range (UTC-aware datetime, inclusive)
    period_to    : end of the date range (UTC-aware datetime, exclusive)
    """
    # Build the initial URL with query parameters for the date range and page size.
    params = {
        "page_size": PAGE_SIZE,
        "period_from": period_from.isoformat(),
        "period_to": period_to.isoformat(),
    }

    url = (
        f"{BASE_URL}/v1/products/{product_code}"
        f"/electricity-tariffs/{tariff_code}"
        f"/standard-unit-rates/"
        f"?{urllib.parse.urlencode(params)}"
    )

    results = []
    while url:
        try:
            with urllib.request.urlopen(url) as response:
                data = json.loads(response.read())
        except urllib.error.URLError as e:
            # HTTPError is a subclass of URLError. A 404 means the product or
            # tariff code doesn't exist for this region or date range, which is
            # expected for older product codes. All other errors — including
            # non-404 HTTP errors and network failures (timeouts, DNS errors) —
            # are re-raised so the caller sees the failure rather than silently
            # receiving an empty or partial result.
            if isinstance(e, urllib.error.HTTPError) and e.code == HTTP_NOT_FOUND:
                return []
            raise

        # extend() adds each item from data["results"] individually to the list.
        # (append() would instead add the whole sub-list as a single nested item.)
        results.extend(data["results"])
        total = data["count"]

        log.info("  %d / %d rates", len(results), total)

        # The API includes a "next" URL when more pages are available, or null
        # when the current page is the last one.
        url = data.get("next")
        if url:
            time.sleep(REQUEST_DELAY_SECONDS)

    return results


def parse_date(value: str) -> datetime.datetime:
    """Parse a YYYY-MM-DD string into a UTC-aware datetime object."""
    return datetime.datetime.strptime(value, DATE_FORMAT).replace(tzinfo=datetime.timezone.utc)


def fetch_gsp_rates(
    gsp: str,
    period_from: datetime.datetime,
    period_to: datetime.datetime,
) -> dict[str, dict]:
    """Fetch all rates for a single GSP region across all known product codes.

    Because the Agile tariff history spans multiple product codes, each is
    queried in turn. Results are deduplicated by their valid_from timestamp so
    that any overlap between product code date ranges does not produce duplicate
    slots in the output.

    Returns a dict mapping each valid_from timestamp string to its rate record.

    Parameters
    ----------
    gsp         : GSP region suffix, e.g. "C" for London
    period_from : start of the date range (UTC-aware datetime, inclusive)
    period_to   : end of the date range (UTC-aware datetime, exclusive)
    """
    rates = {}
    for product_code in AGILE_PRODUCTS:
        # The tariff code is formed by combining the product code and GSP suffix,
        # e.g. "E-1R-AGILE-24-10-01-C" for the London region.
        tariff_code = f"{TARIFF_PREFIX}-{product_code}-{gsp}"
        log.info("  [%s]", product_code)
        for rate in fetch_unit_rates(product_code, tariff_code, period_from, period_to):
            key = rate["valid_from"]
            if key not in rates:
                rates[key] = rate
    return rates


def main() -> None:
    """Run the full data collection pipeline."""
    period_from = parse_date(DATE_FROM)
    period_to = parse_date(DATE_TO)

    log.info(
        "Fetching Agile prices for all %d GSP regions from %s to %s",
        len(GSP_CODES),
        period_from.date(),
        period_to.date() - datetime.timedelta(days=1),  # Display inclusive end date
    )

    rows = []

    for i, gsp in enumerate(GSP_CODES, 1):
        log.info("[%s — %s] (%d/%d)", gsp, GSP_REGIONS[gsp], i, len(GSP_CODES))
        for valid_from, rate in sorted(fetch_gsp_rates(gsp, period_from, period_to).items()):
            rows.append({
                "valid_from": valid_from,
                "valid_to": rate.get("valid_to") or "",
                "gsp": gsp,
                "value_inc_vat": rate["value_inc_vat"],
            })

    if not rows:
        log.error("No data found for the specified range.")
        sys.exit(1)

    # Create the data directory if it does not already exist, then write the CSV.
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=OUTPUT_FIELDNAMES)
        writer.writeheader()
        writer.writerows(rows)

    log.info("Saved %d rates to %s", len(rows), OUTPUT_PATH)


# This block ensures main() is only called when the script is run directly
# (e.g. "python3 collect_agile_octopus_price_data.py"), not when it is imported
# as a module by another Python script.
if __name__ == "__main__":
    main()
