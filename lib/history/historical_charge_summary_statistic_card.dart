import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoricalChargeSummaryStatisticCard extends StatelessWidget {
  const HistoricalChargeSummaryStatisticCard({
    super.key,
    required this.label,
    required this.value,
  });

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
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}
