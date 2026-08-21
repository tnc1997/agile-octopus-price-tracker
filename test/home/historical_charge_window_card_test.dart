import 'package:agile_octopus_price_tracker/home/historical_charge_window_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'HistoricalChargeWindowCard',
    () {
      testWidgets(
        'colors the value using calculatePriceColor for the given colorStops',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeWindowCard(
                  colorStops: colorStops,
                  label: 'Avoid',
                  sublabel: '17:00 - 17:30',
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
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeWindowCard(
                  colorStops: colorStops,
                  label: 'Current',
                  sublabel: '17:00 - 17:30',
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
        'omits the prefix from the value text when prefix is null',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeWindowCard(
                  colorStops: colorStops,
                  label: 'Current',
                  sublabel: '17:00 - 17:30',
                  value: 12.3,
                ),
              ),
            ),
          );

          expect(
            find.text('12.30'),
            findsOneWidget,
          );

          expect(
            find.textContaining('avg'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'prepends the prefix followed by a space to the formatted value when prefix is set',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeWindowCard(
                  colorStops: colorStops,
                  label: 'Best',
                  prefix: 'avg',
                  sublabel: '17:00 - 19:00',
                  value: 12.3,
                ),
              ),
            ),
          );

          expect(
            find.text('avg 12.30'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders the label text',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeWindowCard(
                  colorStops: colorStops,
                  label: 'Best',
                  sublabel: '17:00 - 19:00',
                  value: 12.3,
                ),
              ),
            ),
          );

          expect(
            find.text('Best'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders the sublabel text',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeWindowCard(
                  colorStops: colorStops,
                  label: 'Best',
                  sublabel: '17:00 - 19:00',
                  value: 12.3,
                ),
              ),
            ),
          );

          expect(
            find.text('17:00 - 19:00'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
