import 'package:agile_octopus_price_tracker/common/chart_legend_wrap.dart';
import 'package:agile_octopus_price_tracker/forecast/forecast_service.dart';
import 'package:agile_octopus_price_tracker/home/historical_charge_chart.dart';
import 'package:agile_octopus_price_tracker/home/historical_charge_chart_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

void main() {
  group(
    'HistoricalChargeChartCard',
    () {
      testWidgets(
        'passes colorStops, forecastCharges and historicalCharges through to HistoricalChargeChart',
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
                body: HistoricalChargeChartCard(
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

          final chart = tester.widget<HistoricalChargeChart>(
            find.byType(HistoricalChargeChart),
          );

          expect(
            chart.colorStops,
            colorStops,
          );

          expect(
            chart.forecastCharges,
            forecastCharges,
          );

          expect(
            chart.historicalCharges,
            historicalCharges,
          );
        },
      );

      testWidgets(
        'renders a Card containing a ChartLegendWrap and a HistoricalChargeChart',
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
                body: HistoricalChargeChartCard(
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

          expect(
            find.byType(Card),
            findsOneWidget,
          );

          expect(
            find.byType(ChartLegendWrap),
            findsOneWidget,
          );

          expect(
            find.byType(HistoricalChargeChart),
            findsOneWidget,
          );
        },
      );
    },
  );
}
