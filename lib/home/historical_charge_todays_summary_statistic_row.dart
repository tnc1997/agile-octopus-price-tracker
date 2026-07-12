import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/functions.dart';

/// A 'label: value' row for one of [HistoricalChargeTodaysSummaryCard]'s four
/// headline statistics, coloring the value by [colorStops] like every other
/// rate in this app.
class HistoricalChargeTodaysSummaryStatisticRow extends StatelessWidget {
  const HistoricalChargeTodaysSummaryStatisticRow({
    super.key,
    required this.colorStops,
    required this.label,
    required this.value,
  });

  /// The color gradient stops used to color [value] by unit rate.
  final List<(Color, double)> colorStops;

  /// The caption shown to the left of [value], e.g. `'Lowest'`.
  final String label;

  /// The unit rate this row displays, in pence per kilowatt hour.
  final double value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          NumberFormat('0.00').format(value),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: calculatePriceColor(colorStops, value),
              ),
        ),
      ],
    );
  }
}
