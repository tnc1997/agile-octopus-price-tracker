import 'package:agile_octopus_price_tracker/forecast/forecast_service.dart';
import 'package:agile_octopus_price_tracker/home/historical_charge_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

void main() {
  group(
    'HistoricalChargeChart',
    () {
      testWidgets(
        'renders a single series for empty forecastCharges and historicalCharges',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          const forecastCharges = <ForecastCharge>[];

          const historicalCharges = <HistoricalCharge>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeChart(
                  colorStops: colorStops,
                  forecastCharges: forecastCharges,
                  historicalCharges: historicalCharges,
                ),
              ),
            ),
          );

          // Flushes the chart's initial series animation timer so pumping
          // doesn't leave a pending timer behind after the test tears down.
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
        'renders a single series when only historicalCharges is non-empty',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          const forecastCharges = <ForecastCharge>[];

          final historicalCharges = [
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
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeChart(
                  colorStops: colorStops,
                  forecastCharges: forecastCharges,
                  historicalCharges: historicalCharges,
                ),
              ),
            ),
          );

          // Flushes the chart's initial series animation timer so pumping
          // doesn't leave a pending timer behind after the test tears down.
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
        'renders two series when both historicalCharges and forecastCharges are non-empty',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final forecastCharges = [
            ForecastCharge(
              validFrom: DateTime.utc(1970).add(
                const Duration(
                  minutes: 60,
                ),
              ),
              validTo: DateTime.utc(1970).add(
                const Duration(
                  minutes: 90,
                ),
              ),
              valueIncVat: 15.0,
            ),
          ];

          final historicalCharges = [
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
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeChart(
                  colorStops: colorStops,
                  forecastCharges: forecastCharges,
                  historicalCharges: historicalCharges,
                ),
              ),
            ),
          );

          // Flushes the chart's initial series animation timer so pumping
          // doesn't leave a pending timer behind after the test tears down.
          await tester.pumpAndSettle();

          final chart = tester.widget<SfCartesianChart>(
            find.byType(SfCartesianChart),
          );

          expect(
            chart.series.length,
            2,
          );
        },
      );
    },
  );
}
