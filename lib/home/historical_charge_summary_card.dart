import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/functions.dart';

class HistoricalChargeSummaryCard extends StatelessWidget {
  const HistoricalChargeSummaryCard({
    super.key,
    required this.colorStops,
    required this.label,
    required this.sublabel,
    required this.value,
  });

  final List<(Color, double)> colorStops;

  final String label;

  final String sublabel;

  final double value;

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
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: 4.0,
              ),
              child: Text(
                sublabel,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Text(
              NumberFormat('0.00').format(value),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: calculatePriceColor(colorStops, value),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
