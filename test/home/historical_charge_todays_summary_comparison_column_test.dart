import 'package:agile_octopus_price_tracker/home/historical_charge_todays_summary_comparison_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

void main() {
  group(
    'HistoricalChargeTodaysSummaryComparisonColumn',
    () {
      testWidgets(
        'computes hours below as a fraction of an hour when only part of a slot qualifies',
        (tester) async {
          final todaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 10.0,
              valueIncVat: 10.0,
            ),
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 0, 30),
              validTo: DateTime.utc(1970, 1, 1, 1, 0),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          const yesterdaysCharges = <HistoricalCharge>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryComparisonColumn(
                  hoursBelowThreshold: 15.0,
                  tariffComparisonRate: 27.0,
                  todaysCharges: todaysCharges,
                  yesterdaysCharges: yesterdaysCharges,
                ),
              ),
            ),
          );

          // Only the first (10.0, below 15.0) 30 minute slot counts, so the
          // total is 0.5 hours.
          expect(
            find.text('0.5 hours below 15p/kWh'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'formats hoursBelowThreshold with up to two decimal places',
        (tester) async {
          final todaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          const yesterdaysCharges = <HistoricalCharge>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryComparisonColumn(
                  hoursBelowThreshold: 15.5,
                  tariffComparisonRate: 27.0,
                  todaysCharges: todaysCharges,
                  yesterdaysCharges: yesterdaysCharges,
                ),
              ),
            ),
          );

          expect(
            find.text('0 hours below 15.5p/kWh'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'formats tariffComparisonRate with up to two decimal places in the tariff sentence',
        (tester) async {
          final todaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          const yesterdaysCharges = <HistoricalCharge>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryComparisonColumn(
                  hoursBelowThreshold: 15.0,
                  tariffComparisonRate: 27.5,
                  todaysCharges: todaysCharges,
                  yesterdaysCharges: yesterdaysCharges,
                ),
              ),
            ),
          );

          // (27.5 - 20).abs() / 27.5 * 100 ~= 27.27, rounded to 27%.
          expect(
            find.text('27% cheaper than a 27.5p/kWh tariff'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'hides the tariff comparison sentence when tariffComparisonRate is zero',
        (tester) async {
          final todaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          const yesterdaysCharges = <HistoricalCharge>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryComparisonColumn(
                  hoursBelowThreshold: 15.0,
                  tariffComparisonRate: 0.0,
                  todaysCharges: todaysCharges,
                  yesterdaysCharges: yesterdaysCharges,
                ),
              ),
            ),
          );

          expect(
            find.textContaining('tariff'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'hides the yesterday comparison sentence when yesterdaysCharges is empty',
        (tester) async {
          final todaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          const yesterdaysCharges = <HistoricalCharge>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryComparisonColumn(
                  hoursBelowThreshold: 15.0,
                  tariffComparisonRate: 27.0,
                  todaysCharges: todaysCharges,
                  yesterdaysCharges: yesterdaysCharges,
                ),
              ),
            ),
          );

          expect(
            find.textContaining('yesterday'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'shows both the yesterday and tariff comparison sentences when both apply',
        (tester) async {
          final todaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          final yesterdaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1969, 12, 31),
              validTo: DateTime.utc(1969, 12, 31, 0, 30),
              valueExcVat: 10.0,
              valueIncVat: 10.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryComparisonColumn(
                  hoursBelowThreshold: 15.0,
                  tariffComparisonRate: 25.0,
                  todaysCharges: todaysCharges,
                  yesterdaysCharges: yesterdaysCharges,
                ),
              ),
            ),
          );

          // Today's average is 20: (20 - 10).abs() / 10 * 100 = 100% more
          // expensive than yesterday's average of 10; (20 - 25).abs() / 25 *
          // 100 = 20% cheaper than the 25p/kWh tariff.
          expect(
            find.text('100% more expensive than yesterday'),
            findsOneWidget,
          );

          expect(
            find.text('20% cheaper than a 25p/kWh tariff'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows the tariff comparison sentence as more expensive when todaysCharges average exceeds tariffComparisonRate',
        (tester) async {
          final todaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          const yesterdaysCharges = <HistoricalCharge>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryComparisonColumn(
                  hoursBelowThreshold: 15.0,
                  tariffComparisonRate: 10.0,
                  todaysCharges: todaysCharges,
                  yesterdaysCharges: yesterdaysCharges,
                ),
              ),
            ),
          );

          // (20 - 10).abs() / 10 * 100 = 100% more expensive.
          expect(
            find.text('100% more expensive than a 10p/kWh tariff'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
