import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/functions.dart';

class HistoricalChargeSummaryStatisticCard extends StatelessWidget {
  const HistoricalChargeSummaryStatisticCard({
    super.key,
    required this.colorStops,
    required this.label,
    required this.value,
  });

  /// The color gradient stops used to color the value by its unit rate.
  ///
  /// [value] is passed through [calculatePriceColor] so the number is drawn in
  /// the same color as that price on the chart's gradient line; the label
  /// caption keeps the default text color.
  final List<(Color, double)> colorStops;

  /// The caption shown above the value, naming the statistic (e.g. 'Average').
  final String label;

  /// The unit rate this card displays, formatted to two decimal places.
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
