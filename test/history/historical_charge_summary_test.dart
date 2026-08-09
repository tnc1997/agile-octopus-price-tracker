import 'package:agile_octopus_price_tracker/history/historical_charge_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

void main() {
  group(
    'HistoricalChargeSummary',
    () {
      testWidgets(
        'renders the Average, Lowest and Highest labels',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeSummary(
                  colorStops: const [
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  historicalCharges: [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: 10,
                      valueIncVat: 10,
                    ),
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                      validTo: DateTime.utc(1970, 1, 1, 1, 0),
                      valueExcVat: 25,
                      valueIncVat: 25,
                    ),
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970, 1, 1, 1, 0),
                      validTo: DateTime.utc(1970, 1, 1, 1, 30),
                      valueExcVat: 40,
                      valueIncVat: 40,
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('Average'),
            findsOneWidget,
          );

          expect(
            find.text('Lowest'),
            findsOneWidget,
          );

          expect(
            find.text('Highest'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows the average of the charges\' valueIncVat',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeSummary(
                  colorStops: const [
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  historicalCharges: [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: 10,
                      valueIncVat: 10,
                    ),
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                      validTo: DateTime.utc(1970, 1, 1, 1, 0),
                      valueExcVat: 25,
                      valueIncVat: 25,
                    ),
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970, 1, 1, 1, 0),
                      validTo: DateTime.utc(1970, 1, 1, 1, 30),
                      valueExcVat: 40,
                      valueIncVat: 40,
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('25.00'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows the highest charge\'s valueIncVat',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeSummary(
                  colorStops: const [
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  historicalCharges: [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: 10,
                      valueIncVat: 10,
                    ),
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                      validTo: DateTime.utc(1970, 1, 1, 1, 0),
                      valueExcVat: 25,
                      valueIncVat: 25,
                    ),
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970, 1, 1, 1, 0),
                      validTo: DateTime.utc(1970, 1, 1, 1, 30),
                      valueExcVat: 40,
                      valueIncVat: 40,
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('40.00'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows the lowest charge\'s valueIncVat',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeSummary(
                  colorStops: const [
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  historicalCharges: [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: 10,
                      valueIncVat: 10,
                    ),
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                      validTo: DateTime.utc(1970, 1, 1, 1, 0),
                      valueExcVat: 25,
                      valueIncVat: 25,
                    ),
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970, 1, 1, 1, 0),
                      validTo: DateTime.utc(1970, 1, 1, 1, 30),
                      valueExcVat: 40,
                      valueIncVat: 40,
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('10.00'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
