import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';

import '../common/chart_legend_wrap.dart';
import '../forecast/forecast_service.dart';
import 'historical_charge_chart.dart';

class HistoricalChargeChartCard extends StatelessWidget {
  const HistoricalChargeChartCard({
    super.key,
    required this.colorStops,
    required this.forecastCharges,
    required this.historicalCharges,
  });

  final List<(Color, double)> colorStops;

  final List<ForecastCharge> forecastCharges;

  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                bottom: 8.0,
              ),
              child: ChartLegendWrap(
                colorStops: colorStops,
                forecastCharges: forecastCharges,
                historicalCharges: historicalCharges,
              ),
            ),
            HistoricalChargeChart(
              colorStops: colorStops,
              forecastCharges: forecastCharges,
              historicalCharges: historicalCharges,
            ),
          ],
        ),
      ),
    );
  }
}
