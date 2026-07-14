import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';

import '../common/chart_legend_wrap.dart';
import 'historical_charge_chart.dart';

class HistoricalChargeChartCard extends StatelessWidget {
  const HistoricalChargeChartCard({
    super.key,
    required this.colorStops,
    required this.historicalCharges,
  });

  /// The color gradient stops used to color the enclosed chart by unit rate.
  final List<(Color, double)> colorStops;

  /// The confirmed unit rates the enclosed chart plots.
  ///
  /// Expected in ascending `validFrom` order and non-empty; the history screen
  /// renders its empty state instead of this card when there are none.
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
              ),
            ),
            HistoricalChargeChart(
              colorStops: colorStops,
              historicalCharges: historicalCharges,
            ),
          ],
        ),
      ),
    );
  }
}
