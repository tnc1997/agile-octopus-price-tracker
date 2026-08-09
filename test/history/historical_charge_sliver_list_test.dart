import 'package:agile_octopus_price_tracker/common/functions.dart';
import 'package:agile_octopus_price_tracker/history/historical_charge_sliver_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

void main() {
  group(
    'HistoricalChargeSliverList',
    () {
      testWidgets(
        'colors the average, lowest and highest values using calculatePriceColor',
        (tester) async {
          const colorStops = [
            (Colors.green, 15.0),
            (Colors.red, 30.0),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    HistoricalChargeSliverList(
                      colorStops: colorStops,
                      historicalCharges: [
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 1, 12, 0),
                          validTo: DateTime.utc(1970, 1, 1, 12, 30),
                          valueExcVat: 10,
                          valueIncVat: 10,
                        ),
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 1, 12, 30),
                          validTo: DateTime.utc(1970, 1, 1, 13, 0),
                          valueExcVat: 30,
                          valueIncVat: 30,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            tester.widget<Text>(find.text('20.00')).style?.color,
            calculatePriceColor(colorStops, 20.00),
          );

          expect(
            tester.widget<Text>(find.text('10.00')).style?.color,
            calculatePriceColor(colorStops, 10.00),
          );

          expect(
            tester.widget<Text>(find.text('30.00')).style?.color,
            calculatePriceColor(colorStops, 30.00),
          );
        },
      );

      testWidgets(
        'groups charges by calendar day rather than merging same-weekday charges from different dates',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    HistoricalChargeSliverList(
                      colorStops: const [
                        (Colors.green, 15.0),
                        (Colors.red, 30.0),
                      ],
                      historicalCharges: [
                        // Friday, 2 January 1970.
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 2, 12, 0),
                          validTo: DateTime.utc(1970, 1, 2, 12, 30),
                          valueExcVat: 50,
                          valueIncVat: 50,
                        ),
                        // Friday, 9 January 1970 - same weekday name, a week
                        // later, so must not merge with the row above.
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 9, 12, 0),
                          validTo: DateTime.utc(1970, 1, 9, 12, 30),
                          valueExcVat: 5,
                          valueIncVat: 5,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('Friday'),
            findsNWidgets(2),
          );

          expect(
            find.text('January 2'),
            findsOneWidget,
          );

          expect(
            find.text('January 9'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders a Divider between each pair of adjacent day rows',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    HistoricalChargeSliverList(
                      colorStops: const [
                        (Colors.green, 15.0),
                        (Colors.red, 30.0),
                      ],
                      historicalCharges: [
                        // Thursday, 1 January 1970.
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 1, 12, 0),
                          validTo: DateTime.utc(1970, 1, 1, 12, 30),
                          valueExcVat: 10,
                          valueIncVat: 10,
                        ),
                        // Friday, 2 January 1970.
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 2, 12, 0),
                          validTo: DateTime.utc(1970, 1, 2, 12, 30),
                          valueExcVat: 50,
                          valueIncVat: 50,
                        ),
                        // Saturday, 3 January 1970.
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 3, 12, 0),
                          validTo: DateTime.utc(1970, 1, 3, 12, 30),
                          valueExcVat: 20,
                          valueIncVat: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          // 3 rows have 2 dividers between them.
          expect(
            find.byType(Divider),
            findsNWidgets(2),
          );
        },
      );

      testWidgets(
        'renders a row per calendar day',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    HistoricalChargeSliverList(
                      colorStops: const [
                        (Colors.green, 15.0),
                        (Colors.red, 30.0),
                      ],
                      historicalCharges: [
                        // Thursday, 1 January 1970.
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 1, 12, 0),
                          validTo: DateTime.utc(1970, 1, 1, 12, 30),
                          valueExcVat: 10,
                          valueIncVat: 10,
                        ),
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 1, 12, 30),
                          validTo: DateTime.utc(1970, 1, 1, 13, 0),
                          valueExcVat: 30,
                          valueIncVat: 30,
                        ),
                        // Friday, 2 January 1970.
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 2, 12, 0),
                          validTo: DateTime.utc(1970, 1, 2, 12, 30),
                          valueExcVat: 50,
                          valueIncVat: 50,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('Thursday'),
            findsOneWidget,
          );

          expect(
            find.text('Friday'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders rows in the input order when historicalCharges is not chronologically sorted',
        (tester) async {
          // Documents the widget's documented reliance on charges arriving
          // pre-sorted: `groupBy` preserves each group's first-occurrence
          // order, so feeding a later day before an earlier one renders them
          // in THAT order, not chronologically re-sorted.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    HistoricalChargeSliverList(
                      colorStops: const [
                        (Colors.green, 15.0),
                        (Colors.red, 30.0),
                      ],
                      historicalCharges: [
                        // Friday, 2 January 1970, listed first.
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 2, 12, 0),
                          validTo: DateTime.utc(1970, 1, 2, 12, 30),
                          valueExcVat: 50,
                          valueIncVat: 50,
                        ),
                        // Thursday, 1 January 1970, listed second.
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 1, 12, 0),
                          validTo: DateTime.utc(1970, 1, 1, 12, 30),
                          valueExcVat: 10,
                          valueIncVat: 10,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          final januarySecondOffset = tester.getTopLeft(
            find.text('January 2'),
          );

          final januaryFirstOffset = tester.getTopLeft(
            find.text('January 1'),
          );

          expect(
            januarySecondOffset.dy,
            lessThan(januaryFirstOffset.dy),
          );
        },
      );

      testWidgets(
        'shows the average, lowest and highest for a day with multiple charges',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    HistoricalChargeSliverList(
                      colorStops: const [
                        (Colors.green, 15.0),
                        (Colors.red, 30.0),
                      ],
                      historicalCharges: [
                        // Thursday, 1 January 1970.
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 1, 12, 0),
                          validTo: DateTime.utc(1970, 1, 1, 12, 30),
                          valueExcVat: 10,
                          valueIncVat: 10,
                        ),
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 1, 12, 30),
                          validTo: DateTime.utc(1970, 1, 1, 13, 0),
                          valueExcVat: 30,
                          valueIncVat: 30,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('20.00'),
            findsOneWidget,
          );

          expect(
            find.text('10.00'),
            findsOneWidget,
          );

          expect(
            find.text('30.00'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows the same average, lowest and highest for a day with a single charge',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    HistoricalChargeSliverList(
                      colorStops: const [
                        (Colors.green, 15.0),
                        (Colors.red, 30.0),
                      ],
                      historicalCharges: [
                        // Friday, 2 January 1970.
                        HistoricalCharge(
                          validFrom: DateTime.utc(1970, 1, 2, 12, 0),
                          validTo: DateTime.utc(1970, 1, 2, 12, 30),
                          valueExcVat: 50,
                          valueIncVat: 50,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('50.00'),
            findsNWidgets(3),
          );
        },
      );
    },
  );
}
