import 'package:flutter/material.dart';

import '../main.dart';
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
