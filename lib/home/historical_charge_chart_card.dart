import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';

import 'historical_charge_chart.dart';

class HistoricalChargeChartCard extends StatelessWidget {
  const HistoricalChargeChartCard({
    super.key,
    required this.historicalCharges,
  });

  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 16.0,
        ),
        child: HistoricalChargeChart(
          historicalCharges: historicalCharges,
        ),
      ),
    );
  }
}
