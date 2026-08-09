import 'package:agile_octopus_price_tracker/common/chart_legend_wrap.dart';
import 'package:agile_octopus_price_tracker/history/historical_charge_chart.dart';
import 'package:agile_octopus_price_tracker/history/historical_charge_chart_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

void main() {
  group(
    'HistoricalChargeChartCard',
    () {
      testWidgets(
        'hides the Confirmed and Forecast legend row',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeChartCard(
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
        'renders a Card containing a ChartLegendWrap and a HistoricalChargeChart',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeChartCard(
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

          expect(
            find.descendant(
              of: find.byType(Card),
              matching: find.byType(ChartLegendWrap),
            ),
            findsOneWidget,
          );

          expect(
            find.descendant(
              of: find.byType(Card),
              matching: find.byType(HistoricalChargeChart),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'threads colorStops and historicalCharges through to ChartLegendWrap and HistoricalChargeChart',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
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
                  historicalCharges: historicalCharges,
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          final wrap = tester.widget<ChartLegendWrap>(
            find.byType(ChartLegendWrap),
          );

          expect(
            wrap.colorStops,
            colorStops,
          );

          expect(
            wrap.historicalCharges,
            historicalCharges,
          );

          final chart = tester.widget<HistoricalChargeChart>(
            find.byType(HistoricalChargeChart),
          );

          expect(
            chart.colorStops,
            colorStops,
          );

          expect(
            chart.historicalCharges,
            historicalCharges,
          );
        },
      );
    },
  );
}
