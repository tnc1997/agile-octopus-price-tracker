import 'package:agile_octopus_price_tracker/forecast/seasonal_average_lookup_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small, hand-built lookup document with known values, so the logic tests can
/// assert exact results without depending on the real (and regenerated) asset.
///
/// It mirrors the bundled asset's shape: a top-level `generation_thresholds_mw`
/// map (each generation level's inclusive lower bound in MW) and a `lookup` map
/// keyed `gsp -> time of day -> day type -> month -> generation level`. Every
/// node carries its own inline `average_value_inc_vat` and `count`, exactly like
/// the real table — that is what lets a query read a price off whichever node it
/// stops on. The averages and counts here are arbitrary, distinct sentinels (not
/// realistic prices), chosen so each assertion maps to one unambiguous node.
///
/// The thresholds (`low` >= 0, `medium` >= 100, `high` >= 200) drive the
/// `classify` tests: 0 -> low, 100 -> medium (the bound is inclusive), and any
/// large total -> high.
///
/// The `C` region's deepest path — `17:30 -> weekday -> 01 -> low` — is what a
/// January weekday 17:30 slot with zero generation resolves to, which is why the
/// query tests use `DateTime.utc(2026, 1, 5, 17, 30)` with zero generation
/// (January, so Europe/London == UTC and the slot is deterministic). It has a
/// distinct average at every level (1 at the root rising to 5 at the leaf), so a
/// fallback can be pinpointed to the exact node it stopped on, and the counts
/// decrease with depth (1000, 500, 300, 200, 50 from root to leaf) so a rising
/// `minimumCount` walks back up one level at a time.
///
/// `01` also holds a `medium` bucket (6.0) so a query whose summed generation
/// crosses the medium threshold lands there, exercising the column summation;
/// there is deliberately no `high` bucket, so a high-generation query falls back
/// to `01` — the "missing dimension" case.
///
/// The remaining `C` buckets exercise specific fallbacks:
///   - `18:00` is deliberately missing its `count`, so a query for that slot
///     cannot trust the node and must stop on the region root.
///   - `12:00` and `13:00` hold different averages so that a summer instant
///     (12:00 UTC = 13:00 BST) landing on `13:00` proves the Europe/London
///     conversion happened rather than the raw UTC hour being used.
const _lookup = <String, dynamic>{
  'generation_thresholds_mw': {
    'low': 0.0,
    'medium': 100.0,
    'high': 200.0,
  },
  'lookup': {
    'C': {
      'average_value_inc_vat': 1.0,
      'count': 1000,
      '17:30': {
        'average_value_inc_vat': 2.0,
        'count': 500,
        'weekday': {
          'average_value_inc_vat': 3.0,
          'count': 300,
          '01': {
            'average_value_inc_vat': 4.0,
            'count': 200,
            'low': {
              'average_value_inc_vat': 5.0,
              'count': 50,
            },
            'medium': {
              'average_value_inc_vat': 6.0,
              'count': 60,
            },
          },
        },
      },
      '18:00': {
        'average_value_inc_vat': 9.0,
      },
      '12:00': {
        'average_value_inc_vat': 12.0,
        'count': 100,
      },
      '13:00': {
        'average_value_inc_vat': 13.0,
        'count': 100,
      },
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'SeasonalAverageLookupService',
    () {
      late final SeasonalAverageLookupService service;

      setUpAll(
        () {
          service = SeasonalAverageLookupService.fromJson(_lookup);
        },
      );

      group(
        'classify',
        () {
          test(
            'classifies a total at a threshold bound as that level',
            () {
              expect(
                service.classify(100.0),
                'medium',
              );
            },
          );

          test(
            'classifies a very large total as the highest level',
            () {
              expect(
                service.classify(1000000.0),
                'high',
              );
            },
          );

          test(
            'classifies a zero total as the lowest level',
            () {
              expect(
                service.classify(0.0),
                'low',
              );
            },
          );
        },
      );

      group(
        'fromJson',
        () {
          test(
            'throws when there are no generation thresholds',
            () {
              expect(
                () {
                  SeasonalAverageLookupService.fromJson(
                    <String, dynamic>{
                      'generation_thresholds_mw': <String, dynamic>{},
                      'lookup': <String, dynamic>{},
                    },
                  );
                },
                throwsA(
                  isA<StateError>().having(
                    (error) {
                      return error.message;
                    },
                    'message',
                    'The lookup table has no generation thresholds.',
                  ),
                ),
              );
            },
          );
        },
      );

      group(
        'load',
        () {
          test(
            'loads the bundled asset and answers a query',
            () async {
              final service = await SeasonalAverageLookupService.load();

              final actual = service.predict(
                gsp: 'C',
                dateTime: DateTime.utc(2026, 1, 5, 17, 30),
                embeddedWindMw: 0.0,
                embeddedSolarMw: 0.0,
                windMw: 0.0,
              );

              expect(
                actual,
                isNotNaN,
              );
            },
          );
        },
      );

      group(
        'predict',
        () {
          test(
            'accepts the underscored group-identifier form',
            () {
              expect(
                service.predict(
                  gsp: '_C',
                  dateTime: DateTime.utc(2026, 1, 5, 17, 30),
                  embeddedWindMw: 0.0,
                  embeddedSolarMw: 0.0,
                  windMw: 0.0,
                ),
                service.predict(
                  gsp: 'C',
                  dateTime: DateTime.utc(2026, 1, 5, 17, 30),
                  embeddedWindMw: 0.0,
                  embeddedSolarMw: 0.0,
                  windMw: 0.0,
                ),
              );
            },
          );

          test(
            'converts the instant to Europe/London before bucketing',
            () {
              // 2026-07-01 12:00 UTC is 13:00 BST (summer time); predict must
              // use the 13:00 bucket (13.0), not the raw 12:00 one (12.0).
              expect(
                service.predict(
                  gsp: 'C',
                  dateTime: DateTime.utc(2026, 7, 1, 12, 0),
                  embeddedWindMw: 0.0,
                  embeddedSolarMw: 0.0,
                  windMw: 0.0,
                ),
                13.0,
              );
            },
          );

          test(
            'falls back to a broader bucket when a bucket is below minimumCount',
            () {
              // Each minimumCount excludes the next level down, so the walk stops
              // one node higher: leaf (50) -> 01 (200) -> weekday (300) -> root.
              expect(
                service.predict(
                  gsp: 'C',
                  dateTime: DateTime.utc(2026, 1, 5, 17, 30),
                  embeddedWindMw: 0.0,
                  embeddedSolarMw: 0.0,
                  windMw: 0.0,
                  minimumCount: 51,
                ),
                4.0,
              );

              expect(
                service.predict(
                  gsp: 'C',
                  dateTime: DateTime.utc(2026, 1, 5, 17, 30),
                  embeddedWindMw: 0.0,
                  embeddedSolarMw: 0.0,
                  windMw: 0.0,
                  minimumCount: 201,
                ),
                3.0,
              );

              expect(
                service.predict(
                  gsp: 'C',
                  dateTime: DateTime.utc(2026, 1, 5, 17, 30),
                  embeddedWindMw: 0.0,
                  embeddedSolarMw: 0.0,
                  windMw: 0.0,
                  minimumCount: 100000,
                ),
                1.0,
              );
            },
          );

          test(
            'falls back to a broader bucket when a dimension is missing',
            () {
              // Generation 250 classifies as "high", which has no bucket under
              // 01, so the walk stops on 01 itself.
              expect(
                service.predict(
                  gsp: 'C',
                  dateTime: DateTime.utc(2026, 1, 5, 17, 30),
                  embeddedWindMw: 250.0,
                  embeddedSolarMw: 0.0,
                  windMw: 0.0,
                ),
                4.0,
              );
            },
          );

          test(
            'falls back to a broader bucket when a node is missing its count',
            () {
              // The 18:00 node has no count, so the walk cannot trust it and
              // stops on the region root.
              expect(
                service.predict(
                  gsp: 'C',
                  dateTime: DateTime.utc(2026, 1, 5, 18, 0),
                  embeddedWindMw: 0.0,
                  embeddedSolarMw: 0.0,
                  windMw: 0.0,
                ),
                1.0,
              );
            },
          );

          test(
            'floors the time of day to the half hour',
            () {
              expect(
                service.predict(
                  gsp: 'C',
                  dateTime: DateTime.utc(2026, 1, 5, 17, 47),
                  embeddedWindMw: 0.0,
                  embeddedSolarMw: 0.0,
                  windMw: 0.0,
                ),
                service.predict(
                  gsp: 'C',
                  dateTime: DateTime.utc(2026, 1, 5, 17, 30),
                  embeddedWindMw: 0.0,
                  embeddedSolarMw: 0.0,
                  windMw: 0.0,
                ),
              );
            },
          );

          test(
            'returns the deepest bucket average for a fully specified query',
            () {
              expect(
                service.predict(
                  gsp: 'C',
                  dateTime: DateTime.utc(2026, 1, 5, 17, 30),
                  embeddedWindMw: 0.0,
                  embeddedSolarMw: 0.0,
                  windMw: 0.0,
                ),
                5.0,
              );
            },
          );

          test(
            'sums the forecast columns into the generation level',
            () {
              // 60 + 40 + 0 = 100, which classifies as "medium" and so selects
              // the 01 -> medium bucket (6.0). No single column reaches the
              // medium bound on its own, so this fails unless they are summed.
              expect(
                service.predict(
                  gsp: 'C',
                  dateTime: DateTime.utc(2026, 1, 5, 17, 30),
                  embeddedWindMw: 60.0,
                  embeddedSolarMw: 40.0,
                  windMw: 0.0,
                ),
                6.0,
              );
            },
          );

          test(
            'throws for an unknown region',
            () {
              expect(
                () {
                  return service.predict(
                    gsp: 'Z',
                    dateTime: DateTime.utc(2026, 1, 5, 17, 30),
                    embeddedWindMw: 0.0,
                    embeddedSolarMw: 0.0,
                    windMw: 0.0,
                  );
                },
                throwsA(
                  isA<ArgumentError>().having(
                    (error) {
                      return error.message;
                    },
                    'message',
                    'Unknown region',
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}
