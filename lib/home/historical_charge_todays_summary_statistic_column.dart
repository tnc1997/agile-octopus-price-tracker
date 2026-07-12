import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';

import '../common/extensions.dart';
import 'historical_charge_todays_summary_statistic_row.dart';

/// A widget that displays a vertical column of summary statistics for
/// today's historical charges.
///
/// This widget calculates and presents four key statistics:
/// - Lowest charge value
/// - Highest charge value
/// - Average charge value
/// - Median charge value
///
/// Each statistic is displayed as a [HistoricalChargeTodaysSummaryStatisticRow]
/// with appropriate color mapping based on the provided [colorStops].
class HistoricalChargeTodaysSummaryStatisticColumn extends StatelessWidget {
  const HistoricalChargeTodaysSummaryStatisticColumn({
    super.key,
    required this.colorStops,
    required this.todaysCharges,
  });

  /// The color gradient stops used to color every rate in this column, so
  /// they match the same mapping the chart and the other summary widgets use.
  final List<(Color, double)> colorStops;

  /// The list of historical charges for today used to calculate and display
  /// summary statistics (lowest, highest, average, median).
  final List<HistoricalCharge> todaysCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    var sum = 0.0;
    double? min;
    double? max;
    var length = 0;

    for (final todaysCharge in todaysCharges) {
      sum += todaysCharge.valueIncVat;

      if (min == null || todaysCharge.valueIncVat < min) {
        min = todaysCharge.valueIncVat;
      }

      if (max == null || todaysCharge.valueIncVat > max) {
        max = todaysCharge.valueIncVat;
      }

      length++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8.0,
      children: [
        if (min != null)
          HistoricalChargeTodaysSummaryStatisticRow(
            colorStops: colorStops,
            label: 'Lowest',
            value: min,
          ),
        if (max != null)
          HistoricalChargeTodaysSummaryStatisticRow(
            colorStops: colorStops,
            label: 'Highest',
            value: max,
          ),
        HistoricalChargeTodaysSummaryStatisticRow(
          colorStops: colorStops,
          label: 'Average',
          value: sum / length,
        ),
        HistoricalChargeTodaysSummaryStatisticRow(
          colorStops: colorStops,
          label: 'Median',
          value: todaysCharges.map(
            (todaysCharge) {
              return todaysCharge.valueIncVat;
            },
          ).median,
        ),
      ],
    );
  }
}
