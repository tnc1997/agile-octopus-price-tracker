import 'package:agile_octopus_price_tracker/home/historical_charge_todays_summary_comparison_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'HistoricalChargeTodaysSummaryComparisonText',
    () {
      testWidgets(
        'colors the percentage green when percentage is negative',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeTodaysSummaryComparisonText(
                  percentage: -30.0,
                  suffix: ' than yesterday',
                ),
              ),
            ),
          );

          final text = tester.widget<Text>(
            find.byType(Text),
          );

          final span = text.textSpan! as TextSpan;

          expect(
            span.children![0].style!.color,
            const Color(0xff00ff00),
          );
        },
      );

      testWidgets(
        'colors the percentage red when percentage is exactly zero',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeTodaysSummaryComparisonText(
                  percentage: 0.0,
                  suffix: ' than yesterday',
                ),
              ),
            ),
          );

          final text = tester.widget<Text>(
            find.byType(Text),
          );

          final span = text.textSpan! as TextSpan;

          expect(
            span.children![0].style!.color,
            const Color(0xffff0000),
          );

          expect(
            (span.children![1] as TextSpan).text,
            ' more expensive than yesterday',
          );
        },
      );

      testWidgets(
        'colors the percentage red when percentage is positive',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeTodaysSummaryComparisonText(
                  percentage: 12.0,
                  suffix: ' than yesterday',
                ),
              ),
            ),
          );

          final text = tester.widget<Text>(
            find.byType(Text),
          );

          final span = text.textSpan! as TextSpan;

          expect(
            span.children![0].style!.color,
            const Color(0xffff0000),
          );
        },
      );

      testWidgets(
        'renders the exact suffix text passed in, unmodified',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeTodaysSummaryComparisonText(
                  percentage: -15.0,
                  suffix: ' than a 27p/kWh tariff',
                ),
              ),
            ),
          );

          expect(
            find.text('15% cheaper than a 27p/kWh tariff'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'rounds the absolute percentage to the nearest whole number',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeTodaysSummaryComparisonText(
                  percentage: -30.6,
                  suffix: ' than yesterday',
                ),
              ),
            ),
          );

          expect(
            find.text('31% cheaper than yesterday'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows more expensive wording and text for a positive percentage',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeTodaysSummaryComparisonText(
                  percentage: 12.0,
                  suffix: ' than yesterday',
                ),
              ),
            ),
          );

          expect(
            find.text('12% more expensive than yesterday'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'uses the absolute value of a negative percentage in the displayed text',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeTodaysSummaryComparisonText(
                  percentage: -30.0,
                  suffix: ' than yesterday',
                ),
              ),
            ),
          );

          expect(
            find.text('30% cheaper than yesterday'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
