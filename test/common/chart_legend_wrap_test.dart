import 'package:agile_octopus_price_tracker/common/chart_legend_wrap.dart';
import 'package:agile_octopus_price_tracker/forecast/forecast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

void main() {
  group(
    'ChartLegendWrap',
    () {
      testWidgets(
        'hides Confirmed and Forecast when forecastCharges is empty (the default)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ChartLegendWrap(
                  colorStops: const [
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  historicalCharges: [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: 20,
                      valueIncVat: 20,
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('Confirmed'),
            findsNothing,
          );

          expect(
            find.text('Forecast'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'hides Negative when no charge has a negative valueIncVat',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ChartLegendWrap(
                  colorStops: const [
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  historicalCharges: [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: 20,
                      valueIncVat: 20,
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('Negative'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'shows Cheap and Expensive regardless of negative or forecast state',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ChartLegendWrap(
                  colorStops: const [
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  historicalCharges: [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: 20,
                      valueIncVat: 20,
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('Cheap'),
            findsOneWidget,
          );

          expect(
            find.text('Expensive'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows Confirmed and Forecast when forecastCharges is non-empty',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ChartLegendWrap(
                  colorStops: const [
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  forecastCharges: [
                    ForecastCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueIncVat: 20,
                    ),
                  ],
                  historicalCharges: [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: 20,
                      valueIncVat: 20,
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('Confirmed'),
            findsOneWidget,
          );

          expect(
            find.text('Forecast'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows Negative when a forecast charge has a negative valueIncVat',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ChartLegendWrap(
                  colorStops: const [
                    (Colors.cyan, -1.0),
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  forecastCharges: [
                    ForecastCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueIncVat: -5.0,
                    ),
                  ],
                  historicalCharges: [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: 20,
                      valueIncVat: 20,
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('Negative'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows Negative when a historical charge has a negative valueIncVat',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ChartLegendWrap(
                  colorStops: const [
                    (Colors.cyan, -1.0),
                    (Colors.green, 15.0),
                    (Colors.red, 30.0),
                  ],
                  historicalCharges: [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: -10,
                      valueIncVat: -10,
                    ),
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                      validTo: DateTime.utc(1970, 1, 1, 1, 0),
                      valueExcVat: 20,
                      valueIncVat: 20,
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(
            find.text('Negative'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
