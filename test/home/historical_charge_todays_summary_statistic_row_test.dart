import 'package:agile_octopus_price_tracker/home/historical_charge_todays_summary_statistic_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'HistoricalChargeTodaysSummaryStatisticRow',
    () {
      testWidgets(
        'colors the value using the color stop below it when value is below the first stop',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryStatisticRow(
                  colorStops: const [
                    (Colors.green, 10.0),
                    (Colors.red, 30.0),
                  ],
                  label: 'Lowest',
                  value: 5.0,
                ),
              ),
            ),
          );

          final text = tester.widget<Text>(
            find.text('5.00'),
          );

          expect(
            text.style!.color,
            Colors.green,
          );
        },
      );

      testWidgets(
        'colors the value using the last color stop when value is at or beyond it',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryStatisticRow(
                  colorStops: const [
                    (Colors.green, 10.0),
                    (Colors.red, 30.0),
                  ],
                  label: 'Highest',
                  value: 35.0,
                ),
              ),
            ),
          );

          final text = tester.widget<Text>(
            find.text('35.00'),
          );

          expect(
            text.style!.color,
            Colors.red,
          );
        },
      );

      testWidgets(
        'formats the value to two decimal places',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryStatisticRow(
                  colorStops: const [
                    (Colors.green, 10.0),
                    (Colors.red, 30.0),
                  ],
                  label: 'Average',
                  value: 15.5,
                ),
              ),
            ),
          );

          expect(
            find.text('15.50'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'interpolates the value color between two color stops it falls between',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeTodaysSummaryStatisticRow(
                  colorStops: colorStops,
                  label: 'Median',
                  value: 20.0,
                ),
              ),
            ),
          );

          final text = tester.widget<Text>(
            find.text('20.00'),
          );

          // Value is exactly midway between the two color stops, so the
          // interpolated color is exactly midway between green and red.
          final expectedColor = Color.lerp(
            Colors.green,
            Colors.red,
            0.5,
          );

          expect(
            text.style!.color,
            expectedColor,
          );
        },
      );

      testWidgets(
        'renders the label text unchanged',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryStatisticRow(
                  colorStops: const [
                    (Colors.green, 10.0),
                    (Colors.red, 30.0),
                  ],
                  label: 'Lowest',
                  value: 12.34,
                ),
              ),
            ),
          );

          expect(
            find.text('Lowest'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'rounds the formatted value to two decimal places',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryStatisticRow(
                  colorStops: const [
                    (Colors.green, 10.0),
                    (Colors.red, 30.0),
                  ],
                  label: 'Average',
                  value: 12.345,
                ),
              ),
            ),
          );

          expect(
            find.text('12.35'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
