import 'package:agile_octopus_price_tracker/home/historical_charge_todays_summary_statistic_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

void main() {
  group(
    'HistoricalChargeTodaysSummaryStatisticColumn',
    () {
      testWidgets(
        'computes the average as the mean of every charge in the list',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

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
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 1, 0),
              validTo: DateTime.utc(1970, 1, 1, 1, 30),
              valueExcVat: 60.0,
              valueIncVat: 60.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryStatisticColumn(
                  colorStops: colorStops,
                  todaysCharges: todaysCharges,
                ),
              ),
            ),
          );

          // (10 + 20 + 60) / 3 = 30.
          expect(
            find.text('30.00'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'computes the median as the average of the two middle values of an even-length list',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

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
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 1, 0),
              validTo: DateTime.utc(1970, 1, 1, 1, 30),
              valueExcVat: 30.0,
              valueIncVat: 30.0,
            ),
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 1, 30),
              validTo: DateTime.utc(1970, 1, 1, 2, 0),
              valueExcVat: 100.0,
              valueIncVat: 100.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryStatisticColumn(
                  colorStops: colorStops,
                  todaysCharges: todaysCharges,
                ),
              ),
            ),
          );

          // Sorted: 10, 20, 30, 100 -> median is (20 + 30) / 2 = 25.
          expect(
            find.text('25.00'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'computes the median as the middle value of an odd-length list',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final todaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 50.0,
              valueIncVat: 50.0,
            ),
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 0, 30),
              validTo: DateTime.utc(1970, 1, 1, 1, 0),
              valueExcVat: 5.0,
              valueIncVat: 5.0,
            ),
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 1, 0),
              validTo: DateTime.utc(1970, 1, 1, 1, 30),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryStatisticColumn(
                  colorStops: colorStops,
                  todaysCharges: todaysCharges,
                ),
              ),
            ),
          );

          // Sorted: 5, 20, 50 -> middle value is 20; the average, (5 + 20 +
          // 50) / 3 = 25, is deliberately different so this only matches the
          // Median row.
          expect(
            find.text('20.00'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders no rows at all for an empty todaysCharges without throwing',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          const todaysCharges = <HistoricalCharge>[];

          // Regression test: Average's `sum / length` and Median's `.median`
          // getter both need at least one element (`.median` throws a
          // RangeError on an empty list) — this widget's only current caller
          // already guards against passing an empty list, but the widget
          // itself must not crash if it ever were.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeTodaysSummaryStatisticColumn(
                  colorStops: colorStops,
                  todaysCharges: todaysCharges,
                ),
              ),
            ),
          );

          expect(
            tester.takeException(),
            isNull,
          );

          expect(
            find.byType(Text),
            findsNothing,
          );
        },
      );

      testWidgets(
        'renders Lowest, Highest, Average and Median in that order',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final todaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 12.0,
              valueIncVat: 12.0,
            ),
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 0, 30),
              validTo: DateTime.utc(1970, 1, 1, 1, 0),
              valueExcVat: 5.0,
              valueIncVat: 5.0,
            ),
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 1, 0),
              validTo: DateTime.utc(1970, 1, 1, 1, 30),
              valueExcVat: 40.0,
              valueIncVat: 40.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryStatisticColumn(
                  colorStops: colorStops,
                  todaysCharges: todaysCharges,
                ),
              ),
            ),
          );

          final texts = tester.widgetList<Text>(
            find.descendant(
              of: find.byType(Column).first,
              matching: find.byType(Text),
            ),
          );

          expect(
            texts.map((text) {
              return text.data;
            }),
            [
              'Lowest',
              '5.00',
              'Highest',
              '40.00',
              'Average',
              '19.00',
              'Median',
              '12.00',
            ],
          );
        },
      );

      testWidgets(
        'shows Lowest and Highest rows with the minimum and maximum values when todaysCharges is non-empty',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final todaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 12.0,
              valueIncVat: 12.0,
            ),
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 0, 30),
              validTo: DateTime.utc(1970, 1, 1, 1, 0),
              valueExcVat: 5.0,
              valueIncVat: 5.0,
            ),
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 1, 0),
              validTo: DateTime.utc(1970, 1, 1, 1, 30),
              valueExcVat: 40.0,
              valueIncVat: 40.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryStatisticColumn(
                  colorStops: colorStops,
                  todaysCharges: todaysCharges,
                ),
              ),
            ),
          );

          expect(
            find.text('Lowest'),
            findsOneWidget,
          );

          expect(
            find.text('5.00'),
            findsOneWidget,
          );

          expect(
            find.text('Highest'),
            findsOneWidget,
          );

          expect(
            find.text('40.00'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows Lowest, Highest, Average and Median all equal to the single value for a one-element list',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final todaysCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 15.0,
              valueIncVat: 15.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeTodaysSummaryStatisticColumn(
                  colorStops: colorStops,
                  todaysCharges: todaysCharges,
                ),
              ),
            ),
          );

          expect(
            find.text('Lowest'),
            findsOneWidget,
          );

          expect(
            find.text('Highest'),
            findsOneWidget,
          );

          expect(
            find.text('Average'),
            findsOneWidget,
          );

          expect(
            find.text('Median'),
            findsOneWidget,
          );

          // Lowest, Highest, Average and Median all equal 15.00 with only one
          // charge, so there are four separate value Texts showing it.
          expect(
            find.text('15.00'),
            findsNWidgets(4),
          );
        },
      );
    },
  );
}
