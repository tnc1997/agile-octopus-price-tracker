import 'package:agile_octopus_price_tracker/history/historical_charge_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

void main() {
  group(
    'HistoricalChargeChart',
    () {
      testWidgets(
        'renders a single series for a non-empty historicalCharges',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeChart(
                  colorStops: const [
                    (Colors.green, 10.0),
                    (Colors.red, 30.0),
                  ],
                  historicalCharges: [
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
                  ],
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          final chart = tester.widget<SfCartesianChart>(
            find.byType(SfCartesianChart),
          );

          expect(
            chart.series.length,
            1,
          );
        },
      );

      testWidgets(
        'renders a single series for an empty historicalCharges',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeChart(
                  colorStops: [
                    (Colors.green, 10.0),
                    (Colors.red, 30.0),
                  ],
                  historicalCharges: [],
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          final chart = tester.widget<SfCartesianChart>(
            find.byType(SfCartesianChart),
          );

          expect(
            chart.series.length,
            1,
          );
        },
      );
    },
  );
}
