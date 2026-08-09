import 'package:agile_octopus_price_tracker/history/historical_charge_period.dart';
import 'package:agile_octopus_price_tracker/history/historical_charge_period_segmented_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'HistoricalChargePeriodSegmentedButton',
    () {
      testWidgets(
        'does not invoke onSelectionChanged when the selected segment is tapped again',
        (tester) async {
          final invocations = <HistoricalChargePeriod>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargePeriodSegmentedButton(
                  selected: HistoricalChargePeriod.sevenDays,
                  onSelectionChanged: invocations.add,
                ),
              ),
            ),
          );

          await tester.tap(
            find.text('7 days'),
          );

          await tester.pumpAndSettle();

          expect(
            invocations,
            isEmpty,
          );
        },
      );

      testWidgets(
        'invokes onSelectionChanged with the new period when a different segment is tapped',
        (tester) async {
          final invocations = <HistoricalChargePeriod>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargePeriodSegmentedButton(
                  selected: HistoricalChargePeriod.sevenDays,
                  onSelectionChanged: invocations.add,
                ),
              ),
            ),
          );

          await tester.tap(
            find.text('30 days'),
          );

          await tester.pumpAndSettle();

          expect(
            invocations,
            [HistoricalChargePeriod.thirtyDays],
          );
        },
      );

      testWidgets(
        'invokes onSelectionChanged with sevenDays when 7 days is tapped',
        (tester) async {
          final invocations = <HistoricalChargePeriod>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargePeriodSegmentedButton(
                  selected: null,
                  onSelectionChanged: invocations.add,
                ),
              ),
            ),
          );

          await tester.tap(
            find.text('7 days'),
          );

          await tester.pumpAndSettle();

          expect(
            invocations,
            [HistoricalChargePeriod.sevenDays],
          );
        },
      );

      testWidgets(
        'invokes onSelectionChanged with thirtyDays when 30 days is tapped',
        (tester) async {
          final invocations = <HistoricalChargePeriod>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargePeriodSegmentedButton(
                  selected: null,
                  onSelectionChanged: invocations.add,
                ),
              ),
            ),
          );

          await tester.tap(
            find.text('30 days'),
          );

          await tester.pumpAndSettle();

          expect(
            invocations,
            [HistoricalChargePeriod.thirtyDays],
          );
        },
      );

      testWidgets(
        'invokes onSelectionChanged with threeMonths when 3 months is tapped',
        (tester) async {
          final invocations = <HistoricalChargePeriod>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargePeriodSegmentedButton(
                  selected: null,
                  onSelectionChanged: invocations.add,
                ),
              ),
            ),
          );

          await tester.tap(
            find.text('3 months'),
          );

          await tester.pumpAndSettle();

          expect(
            invocations,
            [HistoricalChargePeriod.threeMonths],
          );
        },
      );

      testWidgets(
        'invokes onSelectionChanged with twelveMonths when 12 months is tapped',
        (tester) async {
          final invocations = <HistoricalChargePeriod>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargePeriodSegmentedButton(
                  selected: null,
                  onSelectionChanged: invocations.add,
                ),
              ),
            ),
          );

          await tester.tap(
            find.text('12 months'),
          );

          await tester.pumpAndSettle();

          expect(
            invocations,
            [HistoricalChargePeriod.twelveMonths],
          );
        },
      );

      testWidgets(
        'renders no segment as selected when selected is null',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargePeriodSegmentedButton(
                  selected: null,
                  onSelectionChanged: (_) {},
                ),
              ),
            ),
          );

          final button = tester.widget<SegmentedButton<HistoricalChargePeriod>>(
            find.byType(SegmentedButton<HistoricalChargePeriod>),
          );

          expect(
            button.selected,
            isEmpty,
          );
        },
      );

      testWidgets(
        'renders the selected segment as selected',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargePeriodSegmentedButton(
                  selected: HistoricalChargePeriod.thirtyDays,
                  onSelectionChanged: (_) {},
                ),
              ),
            ),
          );

          final button = tester.widget<SegmentedButton<HistoricalChargePeriod>>(
            find.byType(SegmentedButton<HistoricalChargePeriod>),
          );

          expect(
            button.selected,
            {HistoricalChargePeriod.thirtyDays},
          );
        },
      );
    },
  );
}
