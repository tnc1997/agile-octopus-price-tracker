import 'package:agile_octopus_price_tracker/common/functions.dart';
import 'package:agile_octopus_price_tracker/history/historical_charge_summary_statistic_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'HistoricalChargeSummaryStatisticCard',
    () {
      testWidgets(
        'colors the value text using calculatePriceColor',
        (tester) async {
          const colorStops = [
            (Colors.green, 15.0),
            (Colors.red, 30.0),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeSummaryStatisticCard(
                  colorStops: colorStops,
                  label: 'Average',
                  value: 20.0,
                ),
              ),
            ),
          );

          final text = tester.widget<Text>(
            find.text('20.00'),
          );

          expect(
            text.style?.color,
            calculatePriceColor(colorStops, 20.0),
          );
        },
      );

      testWidgets(
        'formats the value to two decimal places',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeSummaryStatisticCard(
                  colorStops: [
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  label: 'Average',
                  value: 12.3,
                ),
              ),
            ),
          );

          expect(
            find.text('12.30'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders the label',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeSummaryStatisticCard(
                  colorStops: [
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  label: 'Lowest',
                  value: 10.0,
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
        'rounds the value when formatting',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeSummaryStatisticCard(
                  colorStops: [
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  label: 'Highest',
                  value: 10.005,
                ),
              ),
            ),
          );

          expect(
            find.text('10.01'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
