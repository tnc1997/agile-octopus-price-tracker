import 'package:agile_octopus_price_tracker/common/functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

/// A [HistoricalCharge] slot starting [start] minutes after a fixed,
/// arbitrary epoch and lasting [duration] minutes, priced at [valueIncVat].
///
/// Using an offset from a fixed instant (rather than wall-clock times) keeps
/// the historicalCharges trivially contiguous or gappy by construction, and sidesteps
/// any timezone/DST concerns since [findCheapestWindow] only ever compares
/// [DateTime]s to each other.
HistoricalCharge _historicalCharge(
  int start,
  double valueIncVat, {
  int duration = 30,
}) {
  final validFrom = DateTime.utc(1970).add(
    Duration(
      minutes: start,
    ),
  );

  final validTo = validFrom.add(
    Duration(
      minutes: duration,
    ),
  );

  return HistoricalCharge(
    validFrom: validFrom,
    validTo: validTo,
    valueExcVat: valueIncVat,
    valueIncVat: valueIncVat,
  );
}

void main() {
  group(
    'findCheapestWindow',
    () {
      test(
        'finds a window shorter than the full list when a longer run is pricier',
        () {
          final historicalCharges = [
            _historicalCharge(0, 1),
            _historicalCharge(30, 1),
            _historicalCharge(60, 1),
            _historicalCharge(90, 1),
            _historicalCharge(120, 1), // cheap run: minutes 0-150 (2.5 hours)
            _historicalCharge(150, 100),
          ];

          final result = findCheapestWindow(
            historicalCharges,
            const Duration(
              hours: 2,
            ),
          );

          expect(
            result,
            isNotNull,
          );

          // Any of the four contiguous 2 hour windows within the cheap run
          // ties at average 1; the earliest-starting one wins.
          expect(
            result!.$1,
            [
              historicalCharges[0],
              historicalCharges[1],
              historicalCharges[2],
              historicalCharges[3]
            ],
          );

          expect(
            result.$2,
            1,
          );
        },
      );

      test(
        'finds the exact window when the historicalCharges span exactly the requested duration',
        () {
          final historicalCharges = [
            _historicalCharge(0, 10),
            _historicalCharge(30, 20),
            _historicalCharge(60, 30),
            _historicalCharge(90, 40),
          ]; // exactly 2 hours, one possible window

          final result = findCheapestWindow(
            historicalCharges,
            const Duration(
              hours: 2,
            ),
          );

          expect(
            result,
            isNotNull,
          );

          expect(
            result!.$1,
            historicalCharges,
          );

          expect(
            result.$2,
            25,
          );
        },
      );

      test(
        'is unaffected by expensive slots outside the winning window',
        () {
          final historicalCharges = [
            _historicalCharge(0, 1000),
            _historicalCharge(30, 1000),
            _historicalCharge(60, 1),
            _historicalCharge(90, 1),
            _historicalCharge(120, 1),
            _historicalCharge(150, 1),
            _historicalCharge(180, 1000),
            _historicalCharge(210, 1000),
          ];

          final result = findCheapestWindow(
            historicalCharges,
            const Duration(
              hours: 2,
            ),
          );

          expect(
            result,
            isNotNull,
          );

          expect(
            result!.$1,
            [
              historicalCharges[2],
              historicalCharges[3],
              historicalCharges[4],
              historicalCharges[5]
            ],
          );

          expect(
            result.$2,
            1,
          );
        },
      );

      test(
        'keeps the earlier-starting window on a tied average',
        () {
          final historicalCharges = [
            _historicalCharge(0, 10),
            _historicalCharge(30, 10),
            _historicalCharge(60, 10),
            _historicalCharge(90, 10), // window A: minutes 0-120, average 10
            _historicalCharge(120, 10),
            _historicalCharge(150, 10),
            _historicalCharge(180, 10), // window B: minutes 60-180, average 10
          ];

          final result = findCheapestWindow(
            historicalCharges,
            const Duration(
              hours: 2,
            ),
          );

          expect(
            result,
            isNotNull,
          );

          expect(
            result!.$1,
            [
              historicalCharges[0],
              historicalCharges[1],
              historicalCharges[2],
              historicalCharges[3]
            ],
          );
        },
      );

      test(
        'picks the cheapest of several overlapping candidate windows',
        () {
          final historicalCharges = [
            _historicalCharge(0, 100), // expensive slot before the cheap run
            _historicalCharge(30, 10),
            _historicalCharge(60, 10),
            _historicalCharge(90, 10),
            _historicalCharge(120, 10), // cheap run: minutes 30-150
            _historicalCharge(150, 100), // expensive slot after the cheap run
          ];

          final result = findCheapestWindow(
            historicalCharges,
            const Duration(
              hours: 2,
            ),
          );

          expect(
            result,
            isNotNull,
          );

          expect(
            result!.$1,
            [
              historicalCharges[1],
              historicalCharges[2],
              historicalCharges[3],
              historicalCharges[4]
            ],
          );

          expect(
            result.$2,
            10,
          );
        },
      );

      test(
        'returns null for a duration of zero when no zero-length slot exists',
        () {
          final historicalCharges = [
            _historicalCharge(0, 10),
            _historicalCharge(30, 10),
          ];

          expect(
            findCheapestWindow(
              historicalCharges,
              Duration.zero,
            ),
            isNull,
          );
        },
      );

      test(
        'returns null for an empty list',
        () {
          expect(
            findCheapestWindow(
              [],
              const Duration(
                hours: 2,
              ),
            ),
            isNull,
          );
        },
      );

      test(
        'returns null when the historicalCharges span less than the requested duration',
        () {
          final historicalCharges = [
            _historicalCharge(0, 10),
            _historicalCharge(30, 10),
            _historicalCharge(60, 10),
          ]; // 90 minutes total, less than the 2 hour window requested

          expect(
            findCheapestWindow(
              historicalCharges,
              const Duration(
                hours: 2,
              ),
            ),
            isNull,
          );
        },
      );

      test(
        'returns null when the only run long enough has a gap in it',
        () {
          final historicalCharges = [
            _historicalCharge(0, 10),
            _historicalCharge(30, 10),
            // gap: period 60-90 missing
            _historicalCharge(90, 10),
            _historicalCharge(120, 10),
          ];

          expect(
            findCheapestWindow(
              historicalCharges,
              const Duration(
                hours: 2,
              ),
            ),
            isNull,
          );
        },
      );

      test(
        'skips over a run separated by a gap when a valid run exists elsewhere',
        () {
          final historicalCharges = [
            _historicalCharge(0, 5),
            _historicalCharge(30, 5),
            // gap: period 60-90 missing, so the window starting at minute 0
            // never reaches 2 hours
            _historicalCharge(90, 1),
            _historicalCharge(120, 1),
            _historicalCharge(150, 1),
            _historicalCharge(180, 1),
          ];

          final result = findCheapestWindow(
            historicalCharges,
            const Duration(
              hours: 2,
            ),
          );

          expect(
            result,
            isNotNull,
          );

          expect(
            result!.$1,
            [
              historicalCharges[2],
              historicalCharges[3],
              historicalCharges[4],
              historicalCharges[5]
            ],
          );

          expect(
            result.$2,
            1,
          );
        },
      );

      test(
        'supports negative valueIncVat, e.g. a negative pricing event',
        () {
          final historicalCharges = [
            _historicalCharge(0, 5),
            _historicalCharge(30, -20),
            _historicalCharge(60, -20),
            _historicalCharge(90, 5),
          ];

          final result = findCheapestWindow(
            historicalCharges,
            const Duration(
              hours: 2,
            ),
          );

          expect(
            result,
            isNotNull,
          );

          expect(
            result!.$2,
            -7.5,
          );
        },
      );

      test(
        'works with non-30-minute slot durations',
        () {
          final historicalCharges = [
            _historicalCharge(0, 10, duration: 60),
            _historicalCharge(60, 5, duration: 60),
            _historicalCharge(120, 20, duration: 60),
          ]; // three 1 hour slots spanning 3 hours

          final result = findCheapestWindow(
            historicalCharges,
            const Duration(
              hours: 2,
            ),
          );

          expect(
            result,
            isNotNull,
          );

          expect(
            result!.$1,
            [historicalCharges[0], historicalCharges[1]],
          );

          expect(
            result.$2,
            7.5,
          );
        },
      );
    },
  );
}
