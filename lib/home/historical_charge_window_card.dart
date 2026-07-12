import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/functions.dart';

class HistoricalChargeWindowCard extends StatelessWidget {
  const HistoricalChargeWindowCard({
    super.key,
    required this.colorStops,
    required this.label,
    this.prefix,
    required this.sublabel,
    required this.value,
  });

  /// The color gradient stops used to color [value] by unit rate.
  final List<(Color, double)> colorStops;

  /// The heading identifying what this card displays, e.g. `'Best'`.
  final String label;

  /// Text shown ahead of [value], e.g. `'avg'` to mark an averaged rather
  /// than a single-slot price. Omitted from the rendered text when `null`.
  final String? prefix;

  /// The time range [value] applies to, shown beneath [label].
  final String sublabel;

  /// The unit rate this card displays, in pence per kilowatt hour.
  final double value;

  @override
  Widget build(
    BuildContext context,
  ) {
    final buffer = StringBuffer();

    if (prefix case final prefix?) {
      buffer.write(prefix);
      buffer.write(' ');
    }

    buffer.write(NumberFormat('0.00').format(value));

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
              '$buffer',
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
