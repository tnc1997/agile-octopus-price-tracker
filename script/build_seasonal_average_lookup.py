#!/usr/bin/env python3
"""
Builds an average seasonal price lookup table from the historical datasets.

Background
----------
The two collection scripts in this directory produce a half-hourly history of
Agile Octopus unit rates (per GSP region) and a half-hourly history of NESO
wind and solar generation forecasts:

  - script/data/agile_octopus_price_data.csv
  - script/data/neso_generation_data.csv

On their own these are large, raw time series. To forecast a plausible price
for a future half-hour slot — before Octopus has actually published it — we
need a compact model of how the price typically behaves. This script builds
that model as a lookup table.

Each historical price is assigned to a "bucket" describing the conditions it
was observed under, and the average price is computed for every bucket. The
buckets are the cross product of four dimensions the issue asks for:

  - time of day       — the half-hour slot, e.g. "08:00" or "17:30"
  - day type          — "weekday" or "weekend"
  - month             — "01" (January) through "12" (December), capturing season
  - generation level  — "low", "medium", or "high" renewable output

Generation level is the bridge between the two datasets: more wind and solar
generally pushes wholesale (and therefore Agile) prices down, so a high-
generation August weekday afternoon looks very different from a low-generation
January weekday evening even at the same clock time.

The table is also keyed by GSP region, because Agile rates differ from one
region to the next. The price collection script deliberately stores per-region
prices so that this table can be tailored to the end-user's Grid Supply Point.

Joining the two datasets
------------------------
NESO settlement dates and periods are defined in UK local (clock) time:
period 1 = 00:00-00:30 local, period 48 = 23:30-24:00 local. The Octopus
prices, by contrast, carry a valid_from timestamp in UTC. To line them up,
each price timestamp is converted to Europe/London local time and reduced to a
(settlement_date, settlement_period) key, which is then looked up against the
generation data.

Note on daylight saving: on the autumn "fall back" day the 01:00-01:59 local
hour occurs twice, so the simple clock-based period number is ambiguous for
those slots (NESO models them as the extra periods 49-50). Affected rows are a
handful per year out of ~1.2 million and have a negligible effect on the
averages, so they are joined on clock time like every other slot. Any price
row with no matching generation record is skipped and counted (see the
unmatched total reported at the end).

Generation level
----------------
For each settlement period the three forecast columns are summed into a single
total renewable figure:

    total = embedded_wind_forecast_mw + embedded_solar_forecast_mw + wind_forecast_mw

The terciles (33rd and 66th percentiles) of this total across the whole history
split every period into "low", "medium", or "high". Computing the thresholds
from the data — rather than hard-coding megawatt values — keeps the three
levels balanced and lets the table adapt automatically as the generation mix
grows over time. The chosen thresholds are recorded in the output under the
top-level "generation_thresholds_mw" key so the consumer can reuse them.

Data sources
------------
  - script/data/agile_octopus_price_data.csv  (collect_agile_octopus_price_data.py)
  - script/data/neso_generation_data.csv      (collect_neso_generation_data.py)

Output
------
assets/seasonal_average_lookup.json

A JSON document with two top-level keys:
  generation_thresholds_mw — the (data-derived) tercile thresholds, given as the
             inclusive lower MW bound of each level, e.g.
             {"low": 0.0, "medium": 6432.0, "high": 11840.0}. A runtime consumer
             sums the NESO forecast columns and picks the highest level whose
             bound that sum reaches, then uses that level to index the table.
             The thresholds travel with the table so they are not hard-coded
             separately and stay in step when the table is regenerated.
  lookup   — the nested table, indexed in this order:
                 gsp -> time_of_day -> day_type -> month -> generation_level
             Each leaf is {"average_value_inc_vat": <p/kWh>, "count": <rows>}.

Fallbacks
---------
Not every combination of conditions occurred historically — e.g. low renewable
generation at midday in April never happened, so that bucket would be missing.
A runtime lookup that needs a price for such a combination would otherwise get
nothing back. To prevent that, every node carries its own price inline — the
"average_value_inc_vat" and "count" fields sit alongside its child dimensions
and hold the average over that node's entire subtree. A consumer walks the path
as far as the data allows and, when the next dimension is absent (or too sparse
to trust), simply reads the price off the node it stopped on. For example, a
query for a low-generation April weekend at 12:00 has no "low" child under
".../04", so it reads ".../04" itself — the average across all generation
levels for that slot.

Because a child is always an object and the two value fields
("average_value_inc_vat" and "count") are always scalars, a consumer can tell
the price fields apart from the child dimensions at every node.

The output is written as minified JSON (no indentation) to keep it small enough
to bundle as a Flutter asset. To inspect it, pipe it through a formatter, e.g.
"python3 -m json.tool assets/seasonal_average_lookup.json".

Usage
-----
  python3 script/build_seasonal_average_lookup.py

No arguments are required. Run the two collection scripts first so that the
input CSVs exist.
"""

from __future__ import annotations  # Allows modern type-hint syntax (list[...], dict[...]) on Python 3.7+

import csv             # Reads the price and generation CSVs and is robust to quoting
import datetime        # Parses the UTC valid_from timestamps from the price CSV
import json            # Serialises the finished lookup table to disk
import logging         # Emits timestamped progress messages while processing 1.2M rows
import os              # Builds input/output paths relative to this script
import statistics      # Computes the generation-level quantile thresholds
import sys             # Exits with a non-zero code when an input file is missing
import zoneinfo        # Converts UTC price timestamps to UK local clock time for the join

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# os.path.dirname(__file__) is the "script/" directory that contains this file,
# so the paths below resolve correctly regardless of the current directory.
DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

# Input CSVs produced by the two collection scripts.
PRICE_PATH = os.path.join(DATA_DIR, "agile_octopus_price_data.csv")
GENERATION_PATH = os.path.join(DATA_DIR, "neso_generation_data.csv")

# Output lookup table. Written to the app's assets directory (tracked in version
# control) rather than the git-ignored script/data directory used for the raw
# inputs, because this file is bundled as a Flutter asset.
OUTPUT_PATH = os.path.join(
    os.path.dirname(__file__), "..", "assets", "seasonal_average_lookup.json"
)

# NESO settlement dates/periods are expressed in UK local clock time. Prices are
# stored in UTC, so we convert them to this zone before deriving the join key.
LOCAL_TZ = zoneinfo.ZoneInfo("Europe/London")

# The three NESO forecast columns that are summed into a single renewable total
# used to classify each settlement period's generation level.
GENERATION_COLUMNS = [
    "embedded_wind_forecast_mw",
    "embedded_solar_forecast_mw",
    "wind_forecast_mw",
]

# The generation buckets, in ascending order of renewable output. This list is
# the single source of truth for the number of levels: compute_thresholds
# derives one quantile cut-point per gap between levels, so adding or removing a
# name here changes the whole pipeline (thresholds, classification, output) with
# no other edits.
GENERATION_LEVELS = ["low", "medium", "high"]

# Octopus stamps valid_from in ISO 8601 with a trailing "Z" for UTC, e.g.
# "2024-01-01T00:00:00Z". Python's fromisoformat accepts "+00:00" but not "Z"
# until 3.11; replacing it keeps the parser happy across versions.
UTC_SUFFIX = "Z"

# Number of decimal places to keep on the averaged prices in the output. Agile
# rates are quoted to four decimal places (e.g. 9.4815 p/kWh), so we match that.
PRICE_PRECISION = 4

# Almost every price row should match a generation period; only a handful per
# year fail to (the DST "fall back" ambiguity). If the match rate drops below
# this, the two inputs are probably misaligned (e.g. a missing year or a
# timezone regression) and the table would be built from partial data, so we
# abort rather than emit a quietly-wrong (or empty) result.
MIN_MATCH_RATIO = 0.99

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)


def load_generation() -> dict[tuple[str, int], float]:
    """Load the NESO data into a lookup from (settlement_date, period) to total renewables.

    Returns a dict mapping each (settlement_date, settlement_period) pair to the
    summed renewable forecast in megawatts. The date is kept as the raw
    "YYYY-MM-DD" string and the period as an int so the key can be reproduced
    directly from a price timestamp during the join.
    """
    generation: dict[tuple[str, int], float] = {}

    with open(GENERATION_PATH, newline="") as f:
        for row in csv.DictReader(f):
            key = (row["settlement_date"], int(row["settlement_period"]))
            # Sum the three forecast columns into one renewable total. The
            # collection script should always populate these, but fail with the
            # offending row rather than a context-free ValueError if one is blank
            # or non-numeric (e.g. a malformed future archive).
            try:
                generation[key] = sum(float(row[col]) for col in GENERATION_COLUMNS)
            except ValueError as e:
                log.error("Non-numeric generation value for %s: %s", key, e)
                sys.exit(1)

    if not generation:
        log.error("No generation rows in %s — is the file empty?", GENERATION_PATH)
        sys.exit(1)

    log.info("Loaded %d generation periods from %s", len(generation), GENERATION_PATH)
    return generation


def compute_thresholds(generation: dict[tuple[str, int], float]) -> dict[str, float]:
    """Return each generation level's inclusive lower MW bound, derived from the data.

    The renewable totals are split into len(GENERATION_LEVELS) equal-frequency
    groups by their quantiles. The lowest level starts at zero; each higher level
    starts at the quantile that separates it from the one below. The returned
    mapping (ascending by bound) is used both to classify rows here and to travel
    with the table, so the build and any consumer apply identical boundaries —
    there is no second, separately-rounded copy that could drift.
    """
    values = list(generation.values())
    if len(values) < len(GENERATION_LEVELS):
        log.error(
            "Only %d generation periods — too few to form %d levels.",
            len(values),
            len(GENERATION_LEVELS),
        )
        sys.exit(1)

    # statistics.quantiles(..., n=k) returns the k-1 interior cut-points that
    # divide the data into k equal-frequency groups. The lowest level's bound is
    # 0.0; the rest are those cut-points, rounded for a tidy published value.
    cuts = statistics.quantiles(values, n=len(GENERATION_LEVELS))
    bounds = [0.0] + [round(cut, 1) for cut in cuts]
    return dict(zip(GENERATION_LEVELS, bounds))


def classify_generation(total: float, thresholds: dict[str, float]) -> str:
    """Map a renewable total (MW) to a generation level.

    thresholds maps each level to its inclusive lower bound in ascending order;
    the level is the highest one whose bound the total reaches. This is exactly
    the rule a consumer applies to the published thresholds, so build-time and
    runtime classification cannot disagree.
    """
    level = next(iter(thresholds))  # lowest level (bound 0.0) is the default
    for name, bound in thresholds.items():
        if total < bound:
            break  # ascending bounds, so no higher level can match either
        level = name
    return level


def derive_fields(
    valid_from: str,
    generation: dict[tuple[str, int], float],
    thresholds: dict[str, float],
) -> tuple[str, str, str, str] | None:
    """Derive the timestamp-only bucket fields for a price row's valid_from.

    Returns (time_of_day, day_type, month, generation_level), or None when no
    generation reading matches the slot (e.g. a DST "fall back" ambiguity).

    Every value here depends solely on the timestamp, not the GSP region, so the
    caller caches the result and reuses it across the 14 per-region rows that
    share the same valid_from — avoiding ~14x of the expensive datetime work.
    """
    # Parse the UTC timestamp and convert it to UK local clock time so it aligns
    # with the NESO settlement date/period convention.
    iso = valid_from.replace(UTC_SUFFIX, "+00:00")
    local_dt = datetime.datetime.fromisoformat(iso).astimezone(LOCAL_TZ)

    # Settlement period 1 = 00:00-00:30 local, so the period number is the count
    # of completed half hours since local midnight, plus one.
    period = local_dt.hour * 2 + local_dt.minute // 30 + 1
    total = generation.get((local_dt.date().isoformat(), period))
    if total is None:
        return None

    return (
        f"{local_dt.hour:02d}:{local_dt.minute:02d}",                  # time_of_day
        "weekend" if local_dt.weekday() >= 5 else "weekday",           # day_type
        f"{local_dt.month:02d}",                                       # month
        classify_generation(total, thresholds),                        # generation_level
    )


def _convert(node) -> tuple[dict, float, int]:
    """Turn a [sum, count] totals tree into the output tree, adding inline prices.

    Walks the accumulator bottom-up in a single pass, returning a triple of
    (output node, subtree sum, subtree count). The sum and count bubble up so
    that every node can store its own average — over everything beneath it —
    inline, without re-walking its subtree.

    A [sum, count] list is a leaf: it becomes a node with only the value fields.
    A dict is an interior node: its children are converted first (with sorted
    keys so the output is deterministic), then its own value fields are added
    alongside them.
    """
    if isinstance(node, list):
        total, count = node
        leaf = {
            "average_value_inc_vat": round(total / count, PRICE_PRECISION),
            "count": count,
        }
        return leaf, total, count

    out: dict = {}
    subtotal = 0.0
    subcount = 0
    for key in sorted(node):
        child, child_total, child_count = _convert(node[key])
        out[key] = child
        subtotal += child_total
        subcount += child_count

    # This node's own average over its entire subtree, stored inline alongside
    # its children. A consumer that cannot descend further (the child dimension
    # is absent or too sparse) reads these fields directly, so every node is
    # itself a usable price.
    out["average_value_inc_vat"] = round(subtotal / subcount, PRICE_PRECISION)
    out["count"] = subcount
    return out, subtotal, subcount


def build_lookup() -> dict:
    """Join the datasets, bucket every price, and return the lookup document.

    Streams the (large) price CSV row by row, derives each row's bucket from its
    timestamp and the matching generation reading, and accumulates a running sum
    and count per bucket. Averages are computed at the end. The return value is
    the full document (generation_thresholds_mw + lookup) ready to be serialised to JSON.
    """
    generation = load_generation()
    thresholds = compute_thresholds(generation)
    log.info(
        "Generation thresholds (MW): %s",
        ", ".join(f"{level} >= {bound:g}" for level, bound in thresholds.items()),
    )

    # Nested defaultdict-free accumulator. Each bucket maps to a [sum, count]
    # pair; we use plain dicts with setdefault so the structure stays JSON-like.
    # Key path: gsp -> time_of_day -> day_type -> month -> generation_level.
    totals: dict = {}

    # Cache of timestamp-derived fields, keyed by the raw valid_from string. The
    # 14 per-region rows that share a timestamp resolve to the same fields, so
    # this computes each unique timestamp once instead of ~14 times. A cached
    # value of None means the slot is unmatched, so a sentinel (not None) marks a
    # cache miss — and a single .get keeps the hot cache-hit path to one lookup.
    derived: dict[str, tuple[str, str, str, str] | None] = {}
    cache_miss = object()

    rows_total = 0
    rows_matched = 0

    with open(PRICE_PATH, newline="") as f:
        for row in csv.DictReader(f):
            rows_total += 1

            valid_from = row["valid_from"]
            fields = derived.get(valid_from, cache_miss)
            if fields is cache_miss:
                fields = derive_fields(valid_from, generation, thresholds)
                derived[valid_from] = fields

            if fields is None:
                # No generation reading for this slot (e.g. a DST "fall back"
                # ambiguity). Skip it; the unmatched count is reported below.
                continue
            rows_matched += 1
            time_of_day, day_type, month, level = fields

            # Walk/create the nested dict down to the leaf [sum, count] pair.
            bucket = (
                totals
                .setdefault(row["gsp"], {})
                .setdefault(time_of_day, {})
                .setdefault(day_type, {})
                .setdefault(month, {})
                .setdefault(level, [0.0, 0])
            )
            bucket[0] += float(row["value_inc_vat"])
            bucket[1] += 1

            if rows_total % 200_000 == 0:
                log.info("  processed %d price rows", rows_total)

    log.info(
        "Processed %d price rows (%d matched, %d unmatched)",
        rows_total,
        rows_matched,
        rows_total - rows_matched,
    )

    # If no rows matched, or a large share failed to, the inputs are probably
    # misaligned and the table would be built from partial (or no) data. Abort
    # rather than silently writing a quietly-wrong asset that still exits 0.
    if not rows_total or rows_matched / rows_total < MIN_MATCH_RATIO:
        log.error(
            "Only %d of %d price rows matched a generation period (need >= %.0f%%) "
            "— check the price and generation inputs cover the same dates.",
            rows_matched,
            rows_total,
            100 * MIN_MATCH_RATIO,
        )
        sys.exit(1)

    # Convert each GSP's subtree independently. Done per region (rather than
    # calling _convert on the whole tree) so that no cross-region average is
    # produced: Agile rates are region-specific, so a price averaged over
    # different regions would be meaningless. Within a region, _convert adds the
    # inline fallback prices at every node.
    lookup = {gsp: _convert(totals[gsp])[0] for gsp in sorted(totals)}

    # Only the generation-level classifier travels with the table: the runtime
    # consumer is given raw NESO megawatts and must reuse these exact, data-
    # derived thresholds to choose a bucket. Everything else (sources, row
    # counts, timestamps) was pure provenance and is intentionally omitted to
    # keep the bundled asset minimal.
    return {
        # The exact same mapping used to classify rows above: each level's
        # inclusive lower MW bound, ascending. A consumer sums the NESO forecast
        # columns and picks the highest level whose bound that sum reaches.
        "generation_thresholds_mw": thresholds,
        "lookup": lookup,
    }


def main() -> None:
    """Build the lookup table and write it to OUTPUT_PATH as JSON."""
    for path in (PRICE_PATH, GENERATION_PATH):
        if not os.path.exists(path):
            log.error("Input file not found: %s", path)
            log.error("Run the data collection scripts first.")
            sys.exit(1)

    document = build_lookup()

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w") as f:
        # Minified (no whitespace) to keep the bundled Flutter asset small.
        # Pipe through "python3 -m json.tool" if you need to read it.
        json.dump(document, f, separators=(",", ":"))

    log.info("Saved lookup table to %s", OUTPUT_PATH)


# Only run main() when executed directly, not when imported as a module.
if __name__ == "__main__":
    main()
