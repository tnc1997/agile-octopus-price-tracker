import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';

import 'historical_charge_todays_summary_comparison_text.dart';

/// The bottom comparison section of `HistoricalChargeTodaysSummaryCard`: the
/// divider, the 'hours below' sentence, and the yesterday and tariff
/// comparison sentences.
///
/// The yesterday sentence is omitted when [yesterdaysCharges] is empty (the
/// caller-supplied list doesn't cover yesterday); both comparison sentences
/// are omitted individually when their reference point isn't strictly
/// positive, per [_describeComparison].
class HistoricalChargeTodaysSummaryComparisonColumn extends StatelessWidget {
  /// The threshold, in pence per kilowatt hour, the 'below' row counts
  /// against.
  static const _belowThreshold = 15.00;

  const HistoricalChargeTodaysSummaryComparisonColumn({
    super.key,
    required this.tariffComparisonRate,
    required this.todaysCharges,
    required this.yesterdaysCharges,
  });

  /// The flat-rate tariff, in pence per kilowatt hour, today's average is
  /// compared against.
  ///
  /// Sourced from the user-configurable `tariff_comparison_rate`
  /// preference (see [getTariffComparisonRate] in `lib/common/functions.dart`),
  /// rather than a hard-coded constant, so this sentence reflects the user's
  /// actual alternative tariff rate.
  final double tariffComparisonRate;

  /// Today's charges, used for the 'hours below' sentence and today's
  /// average.
  final List<HistoricalCharge> todaysCharges;

  /// Yesterday's charges, used for the yesterday comparison sentence; that
  /// sentence is omitted when this is empty.
  final List<HistoricalCharge> yesterdaysCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    var below = Duration.zero;

    for (final todaysCharge in todaysCharges) {
      if (todaysCharge.valueIncVat < _belowThreshold) {
        if (todaysCharge.validFrom case final validFrom?) {
          if (todaysCharge.validTo case final validTo?) {
            below += validTo.difference(validFrom);
          }
        }
      }
    }

    final yesterdaysAverage = yesterdaysCharges.map(
      (yesterdaysCharge) {
        return yesterdaysCharge.valueIncVat;
      },
    ).average;

    final todaysAverage = todaysCharges.map(
      (todaysCharge) {
        return todaysCharge.valueIncVat;
      },
    ).average;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8.0,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text:
                    '${NumberFormat('0.#').format(below.inMinutes / 60.0)} hours',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text:
                    ' below ${NumberFormat('0.##').format(_belowThreshold)}p/kWh',
              ),
            ],
          ),
        ),
        if (yesterdaysCharges.isNotEmpty)
          if (_describeComparison(todaysAverage, yesterdaysAverage)
              case final percentage?)
            HistoricalChargeTodaysSummaryComparisonText(
              percentage: percentage,
              suffix: ' than yesterday',
            ),
        if (_describeComparison(todaysAverage, tariffComparisonRate)
            case final percentage?)
          HistoricalChargeTodaysSummaryComparisonText(
            percentage: percentage,
            suffix:
                ' than a ${NumberFormat('0.##').format(tariffComparisonRate)}p/kWh tariff',
          ),
      ],
    );
  }

  /// Describes how [value] compares to [base] as a signed percentage:
  /// positive when [value] exceeds [base] (more expensive), negative when
  /// it's below (cheaper), e.g. `12` for 12% more expensive or `-30` for 30%
  /// cheaper.
  ///
  /// The direction is determined by a plain comparison of [value] and [base],
  /// which holds regardless of sign, while the magnitude is taken relative to
  /// [base]'s absolute value so a negative [base] (Agile Octopus rates can
  /// legitimately be zero or negative during negative-pricing events) doesn't
  /// flip the sign of the result.
  ///
  /// Returns null when [base] is zero, since the percentage difference would
  /// require dividing by zero.
  double? _describeComparison(
    double value,
    double base,
  ) {
    if (base == 0) {
      return null;
    }

    return (value - base).abs() / base.abs() * 100 * (value < base ? -1 : 1);
  }
}
