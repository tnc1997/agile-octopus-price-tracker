import 'package:agile_octopus_price_tracker/home/historical_charge_todays_summary_card.dart';
import 'package:agile_octopus_price_tracker/home/historical_charge_todays_summary_comparison_column.dart';
import 'package:agile_octopus_price_tracker/home/historical_charge_todays_summary_statistic_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

void main() {
  group(
    'HistoricalChargeTodaysSummaryCard',
    () {
      testWidgets(
        'always renders the title text',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          const historicalCharges = <HistoricalCharge>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeTodaysSummaryCard(
                  colorStops: colorStops,
                  historicalCharges: historicalCharges,
                  hoursBelowThreshold: 15.0,
                  tariffComparisonRate: 27.0,
                ),
              ),
            ),
          );

          expect(
            find.text('Today\'s summary'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'hides both child columns when historicalCharges has no charges for today',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final historicalCharges = [
            // Two days ago, so it isn't today's or yesterday's charge.
            HistoricalCharge(
              validFrom: DateTime.now().toUtc().add(
                    Duration(
                      minutes: (-48 * 60).round(),
                    ),
                  ),
              validTo: DateTime.now().toUtc().add(
                    Duration(
                      minutes: (-48 * 60).round() + 30,
                    ),
                  ),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryCard(
                  colorStops: colorStops,
                  historicalCharges: historicalCharges,
                  hoursBelowThreshold: 15.0,
                  tariffComparisonRate: 27.0,
                ),
              ),
            ),
          );

          expect(
            find.byType(HistoricalChargeTodaysSummaryStatisticColumn),
            findsNothing,
          );

          expect(
            find.byType(HistoricalChargeTodaysSummaryComparisonColumn),
            findsNothing,
          );
        },
      );

      testWidgets(
        'shows both child columns when historicalCharges has charges for today but none for yesterday',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final historicalCharges = [
            HistoricalCharge(
              validFrom: DateTime.now().toUtc().add(
                    Duration(
                      minutes: (0 * 60).round(),
                    ),
                  ),
              validTo: DateTime.now().toUtc().add(
                    Duration(
                      minutes: (0 * 60).round() + 30,
                    ),
                  ),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryCard(
                  colorStops: colorStops,
                  historicalCharges: historicalCharges,
                  hoursBelowThreshold: 15.0,
                  tariffComparisonRate: 27.0,
                ),
              ),
            ),
          );

          expect(
            find.byType(HistoricalChargeTodaysSummaryStatisticColumn),
            findsOneWidget,
          );

          expect(
            find.byType(HistoricalChargeTodaysSummaryComparisonColumn),
            findsOneWidget,
          );

          final comparisonColumn =
              tester.widget<HistoricalChargeTodaysSummaryComparisonColumn>(
            find.byType(HistoricalChargeTodaysSummaryComparisonColumn),
          );

          expect(
            comparisonColumn.yesterdaysCharges,
            isEmpty,
          );
        },
      );

      testWidgets(
        'shows both child columns with yesterdaysCharges populated when historicalCharges spans today and yesterday',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final historicalCharges = [
            HistoricalCharge(
              validFrom: DateTime.now().toUtc().add(
                    Duration(
                      minutes: (0 * 60).round(),
                    ),
                  ),
              validTo: DateTime.now().toUtc().add(
                    Duration(
                      minutes: (0 * 60).round() + 30,
                    ),
                  ),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
            HistoricalCharge(
              validFrom: DateTime.now().toUtc().add(
                    Duration(
                      minutes: (-24 * 60).round(),
                    ),
                  ),
              validTo: DateTime.now().toUtc().add(
                    Duration(
                      minutes: (-24 * 60).round() + 30,
                    ),
                  ),
              valueExcVat: 10.0,
              valueIncVat: 10.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryCard(
                  colorStops: colorStops,
                  historicalCharges: historicalCharges,
                  hoursBelowThreshold: 15.0,
                  tariffComparisonRate: 27.0,
                ),
              ),
            ),
          );

          expect(
            find.byType(HistoricalChargeTodaysSummaryStatisticColumn),
            findsOneWidget,
          );

          final comparisonColumn =
              tester.widget<HistoricalChargeTodaysSummaryComparisonColumn>(
            find.byType(HistoricalChargeTodaysSummaryComparisonColumn),
          );

          expect(
            comparisonColumn.yesterdaysCharges.length,
            1,
          );

          expect(
            comparisonColumn.yesterdaysCharges.first.valueIncVat,
            10.0,
          );
        },
      );
    },
  );
}
