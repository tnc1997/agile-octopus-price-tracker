import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A single 'X% cheaper/more expensive than ...' sentence, with only the
/// percentage colored: green when [percentage] is negative (cheaper), red
/// when it's positive (more expensive).
class HistoricalChargeTodaysSummaryComparisonText extends StatelessWidget {
  const HistoricalChargeTodaysSummaryComparisonText({
    super.key,
    required this.percentage,
    required this.suffix,
  });

  /// The signed percentage difference driving both the displayed magnitude
  /// and the cheaper/more expensive wording and color; see
  /// `HistoricalChargeTodaysSummaryComparisonColumn._describeComparison`.
  final double percentage;

  /// The text following the comparison word, e.g. ' than yesterday' or
  /// ' than a 27p/kWh tariff'.
  final String suffix;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${NumberFormat('0').format(percentage.abs())}%',
            style: TextStyle(
              color: percentage < 0
                  ? const Color(0xff00ff00)
                  : const Color(0xffff0000),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: ' ${percentage < 0 ? 'cheaper' : 'more expensive'}$suffix',
          ),
        ],
      ),
    );
  }
}
