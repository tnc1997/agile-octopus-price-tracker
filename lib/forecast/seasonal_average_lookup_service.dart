import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Loads and queries the seasonal average price lookup table.
///
/// The table is built offline by `script/build_seasonal_average_lookup.py` and
/// bundled as the `assets/seasonal_average_lookup.json` asset. It models
/// how the Agile Octopus unit rate typically behaves under a set of conditions
/// so a plausible price can be forecast for a future half-hour slot before
/// Octopus has published it.
///
/// Each price is bucketed by the conditions it was observed under and averaged.
/// The buckets are indexed in this order:
///
///   gsp -> time of day -> day type -> month -> generation level
///
/// Every node also carries its own `average_value_inc_vat` (the average over its
/// entire subtree) inline, so a query walks the path as far as the data allows
/// and reads the price off the deepest node it reaches. A combination that never
/// occurred historically therefore still resolves to a sensible fallback rather
/// than a miss. See the script's module docstring for the full rationale.
class SeasonalAverageLookupService {
  /// Creates a service from already-parsed table data.
  ///
  /// Private so that instances can only be obtained through [load] (or
  /// [fromJson] in tests), which are responsible for reading the asset and
  /// normalizing it (decoding the JSON and sorting the thresholds) into the
  /// shape the fields rely on. This synchronous constructor exists to hold the
  /// finished data once that work is done.
  ///
  /// [thresholds] must already be sorted ascending by bound, as
  /// [classify] scans it in order; [lookup] is the table's
  /// `lookup` object with the inline value fields intact at every node;
  /// [location] is the Europe/London zone the table was bucketed in.
  SeasonalAverageLookupService._({
    required tz.Location location,
    required Map<String, dynamic> lookup,
    required List<({String level, double bound})> thresholds,
  })  : _location = location,
        _lookup = lookup,
        _thresholds = thresholds;

  /// Builds a service from an already-decoded lookup [json] document.
  ///
  /// Exposed for tests so the query logic can be exercised against small,
  /// in-memory tables without reading the bundled asset; [load] delegates here
  /// after decoding the asset. Production code should call [load].
  ///
  /// [json] must have the asset's shape: a `generation_thresholds_mw` map of
  /// level name to MW bound, and a `lookup` map. Throws a [StateError] if there
  /// are no thresholds.
  @visibleForTesting
  factory SeasonalAverageLookupService.fromJson(
    Map<String, dynamic> json,
  ) {
    // Collect each level paired with its bound.
    final thresholds = <({String level, double bound})>[];
    final bounds = json['generation_thresholds_mw'] as Map<String, dynamic>;
    for (final entry in bounds.entries) {
      thresholds.add((
        level: entry.key,
        bound: (entry.value as num).toDouble(),
      ));
    }

    // A table with no thresholds cannot classify generation; fail here with a
    // clear message rather than at the first query with an opaque StateError.
    if (thresholds.isEmpty) {
      throw StateError('The lookup table has no generation thresholds.');
    }

    // Keep the thresholds sorted ascending by bound so classification can scan
    // them in order rather than relying on the document's key order.
    thresholds.sort((a, b) => a.bound.compareTo(b.bound));

    // Resolve Europe/London, the zone the build script bucketed every row in.
    tz.initializeTimeZones();
    final location = tz.getLocation('Europe/London');

    return SeasonalAverageLookupService._(
      location: location,
      thresholds: thresholds,
      lookup: json['lookup'] as Map<String, dynamic>,
    );
  }

  /// The asset key of the bundled lookup table.
  ///
  /// Matches the path declared under `flutter: assets:` in `pubspec.yaml`, which
  /// the build script writes to directly so the bundled asset stays in step with
  /// the table whenever it is regenerated. Passed to [AssetBundle.loadString] by
  /// [load].
  static const _assetKey = 'assets/seasonal_average_lookup.json';

  /// The key of the inline average a node stores for its own subtree.
  ///
  /// Every node — not just the leaves — carries this field, holding the average
  /// price (in pence per kWh, inclusive of VAT) over everything beneath it. A
  /// query reads it off the deepest node it manages to reach. Skipping it (and
  /// [_countKey]) when descending stops a value field from being mistaken for a
  /// child dimension, since children are objects and the value fields are scalars.
  static const _averageValueIncVatKey = 'average_value_inc_vat';

  /// The key of the row count a node stores for its own subtree.
  ///
  /// Holds the number of historical prices averaged into this node's
  /// [_averageValueIncVatKey]. [predict] compares it against `minimumCount` to
  /// decide whether a bucket is dense enough to trust before descending into it.
  /// Skipping it (and [_averageValueIncVatKey]) when descending stops a value
  /// field from being mistaken for a child dimension.
  static const _countKey = 'count';

  /// The Europe/London time zone — the zone the build script bucketed every row
  /// in.
  ///
  /// [predict] converts each incoming instant to this zone before deriving its
  /// time-of-day, day-type and month buckets, so the runtime keys line up with
  /// the build and the caller need not pre-convert (UK clocks shift for British
  /// Summer Time, so the device's own zone cannot be assumed).
  final tz.Location _location;

  /// The nested lookup table, keyed `gsp -> time of day -> day type -> month ->
  /// generation level`.
  ///
  /// Every node is a [Map] whose entries are its child dimensions plus the two
  /// inline value fields ([_averageValueIncVatKey] and [_countKey]). [predict]
  /// walks this structure one dimension at a time. Typed `dynamic` at the values
  /// because a node holds a mix of nested maps (children) and scalars (the value
  /// fields), exactly as decoded from the JSON asset.
  ///
  /// The whole tree is intentionally kept resident for the service's lifetime:
  /// the fallback walk needs the nested structure, so there is no smaller form
  /// to retain.
  final Map<String, dynamic> _lookup;

  /// Each generation level paired with its inclusive lower bound in megawatts,
  /// ascending by bound, e.g. `[(level: 'low', bound: 0.0), (level: 'medium',
  /// bound: 6432.0), (level: 'high', bound: 11840.0)]`.
  ///
  /// Derived from the historical data at build time and shipped with the table
  /// so that runtime classification cannot disagree with how the rows were
  /// bucketed. Held as a sorted list (rather than a map) so
  /// [classify] can scan it in ascending order without depending
  /// on the asset's key order. Sorted once by [load].
  final List<({String level, double bound})> _thresholds;

  /// Loads and parses the bundled lookup table, returning a ready-to-query
  /// service.
  ///
  /// Reads the [_assetKey] asset as a string, decodes the JSON document on a
  /// background isolate, and builds the service from it via [fromJson]. This
  /// work is paid once here; call this during start-up and reuse the returned
  /// instance rather than reloading per query.
  ///
  /// Pass [bundle] to load from a specific [AssetBundle] (e.g. a test bundle);
  /// it defaults to [rootBundle], the application's bundled assets.
  ///
  /// Completes with an error if the asset is missing or its contents do not
  /// match the expected document shape.
  static Future<SeasonalAverageLookupService> load({
    AssetBundle? bundle,
  }) async {
    // Default to the root bundle if none is provided.
    bundle ??= rootBundle;

    // Read the bundled asset as a raw JSON string.
    final data = await bundle.loadString(_assetKey);

    // Decode the ~3.4MB document off the UI isolate so the parse does not jank
    // start-up, then build the service from it.
    final document = await compute(json.decode, data) as Map<String, dynamic>;

    return SeasonalAverageLookupService.fromJson(document);
  }

  /// Classifies a total renewable forecast (in megawatts) into a generation
  /// level, e.g. `"low"`, `"medium"` or `"high"`.
  ///
  /// [total] is the sum of the NESO embedded wind, embedded solar and wind
  /// forecast columns for the slot. The level is the highest one whose bound the
  /// total reaches — exactly the rule the build script applies, so the two
  /// cannot disagree.
  String classify(
    double total,
  ) {
    // The lowest level (bound 0.0) is the default; step up while the total still
    // reaches the next bound. Bounds are ascending, so the first bound the total
    // falls short of ends the walk.
    var level = _thresholds.first.level;

    for (final threshold in _thresholds) {
      if (total < threshold.bound) {
        break;
      }

      level = threshold.level;
    }

    return level;
  }

  /// Forecasts the average unit rate (in pence per kWh, inclusive of VAT) for a
  /// half-hour slot under the given conditions.
  ///
  /// [gsp] is the Grid Supply Point region code. Both the bare letter as it
  /// appears in the table (e.g. `"C"` for London) and the application's stored
  /// group-identifier form with a leading underscore (e.g. `"_C"`) are accepted.
  ///
  /// [dateTime] is the instant of the slot; its own time zone does not matter,
  /// as it is converted to Europe/London — the zone the table was built in —
  /// before the bucket is derived. Its minutes are floored to the half hour, so
  /// any instant within a slot resolves to that slot.
  ///
  /// [embeddedWindMw], [embeddedSolarMw] and [windMw] are the slot's NESO
  /// forecast columns in megawatts. They are summed into the total renewable
  /// forecast and classified via [classify] — the service owns this summation so
  /// it stays in step with how the build script defines generation, exactly as
  /// it owns the thresholds.
  ///
  /// The query descends `time of day -> day type -> month -> generation level`,
  /// stopping at the deepest node that exists and whose `count` is at least
  /// [minimumCount], then returns that node's inline average. Raise
  /// [minimumCount] to fall back to a broader bucket when a leaf is too sparse
  /// to trust.
  ///
  /// Throws an [ArgumentError] if [gsp] is not present in the table.
  double predict({
    required String gsp,
    required DateTime dateTime,
    required double embeddedWindMw,
    required double embeddedSolarMw,
    required double windMw,
    int minimumCount = 1,
  }) {
    // The table is keyed by the bare region letter (e.g. "C"); the app stores
    // the group identifier with a leading underscore (e.g. "_C"), so accept and
    // strip that form too. An unknown region is a caller error.
    final region = _lookup[gsp.startsWith('_') ? gsp.substring(1) : gsp];
    if (region is! Map<String, dynamic>) {
      throw ArgumentError.value(gsp, 'gsp', 'Unknown region');
    }

    // Convert the instant to Europe/London wall-clock time so the derived keys
    // line up with how the build script bucketed each row, regardless of the
    // incoming DateTime's own zone or the device's.
    final local = tz.TZDateTime.from(dateTime, _location);

    // Sum the NESO forecast columns into the single renewable total the build
    // script classifies on, then map it to a generation level.
    final generation = embeddedWindMw + embeddedSolarMw + windMw;

    // The bucket keys for this slot, in descending order of specificity. They
    // mirror how the build script derives a row's bucket from its timestamp.
    final keys = [
      '${local.hour.toString().padLeft(2, '0')}:${local.minute < 30 ? '00' : '30'}',
      local.weekday >= DateTime.saturday ? 'weekend' : 'weekday',
      local.month.toString().padLeft(2, '0'),
      classify(generation),
    ];

    // Start at the region root and descend one dimension at a time, as far as
    // the data supports.
    var node = region;

    for (final key in keys) {
      final child = node[key];

      // Stop as soon as the next dimension is absent, and read the price off the
      // node reached so far.
      if (child is! Map<String, dynamic>) {
        break;
      }

      // Stop if the child's bucket is missing its count or is too sparse to
      // trust, and read the price off the node reached so far.
      final count = child[_countKey];
      if (count is! num || count < minimumCount) {
        break;
      }

      // Otherwise descend into the child and keep walking.
      node = child;
    }

    // Read the inline average off the deepest node the walk reached.
    return (node[_averageValueIncVatKey] as num).toDouble();
  }
}
