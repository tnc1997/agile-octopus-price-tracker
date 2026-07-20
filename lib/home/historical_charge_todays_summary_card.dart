import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';

import 'historical_charge_todays_summary_comparison_column.dart';
import 'historical_charge_todays_summary_statistic_column.dart';

/// A card summarizing today's confirmed unit rates: the day's lowest,
/// highest, average and median prices, how many hours fall below a fixed
/// threshold, and how today's average compares to yesterday's and to a fixed
/// flat-rate tariff.
class HistoricalChargeTodaysSummaryCard extends StatelessWidget {
  const HistoricalChargeTodaysSummaryCard({
    super.key,
    required this.colorStops,
    required this.historicalCharges,
    required this.hoursBelowThreshold,
    required this.tariffComparisonRate,
  });

  /// The color gradient stops used to color every rate on this card, so they
  /// match the same mapping the chart and the other summary widgets use.
  final List<(Color, double)> colorStops;

  /// The charges this card is built from.
  ///
  /// Today's and yesterday's slots are both picked out of this single list —
  /// by comparing each charge's [HistoricalCharge.validFrom] (in local time)
  /// against the current local calendar day — rather than being passed in
  /// separately, so the caller only has to supply one combined list spanning
  /// at least yesterday through today. The yesterday comparison row is
  /// omitted when the list doesn't cover yesterday.
  final List<HistoricalCharge> historicalCharges;

  /// The threshold, in pence per kilowatt hour, the 'hours below' row counts
  /// against. Passed straight through to
  /// [HistoricalChargeTodaysSummaryComparisonColumn].
  final double hoursBelowThreshold;

  /// The flat-rate tariff, in pence per kilowatt hour, that the tariff
  /// comparison sentence compares today's average against. Passed straight
  /// through to [HistoricalChargeTodaysSummaryComparisonColumn].
  final double tariffComparisonRate;

  @override
  Widget build(
    BuildContext context,
  ) {
    // Both boundaries are derived from today's local calendar day — rather
    // than subtracting a fixed 24-hour Duration from `now` — so a daylight
    // saving transition (which can make a local day 23 or 25 hours long)
    // can't shift 'yesterday' onto the wrong calendar day.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    final todaysCharges = _getHistoricalChargesOn(
      historicalCharges,
      today,
    );

    final yesterdaysCharges = _getHistoricalChargesOn(
      historicalCharges,
      yesterday,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16.0,
          children: [
            Text(
              'Today\'s summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (todaysCharges.isNotEmpty) ...[
              HistoricalChargeTodaysSummaryStatisticColumn(
                colorStops: colorStops,
                todaysCharges: todaysCharges,
              ),
              const Divider(),
              HistoricalChargeTodaysSummaryComparisonColumn(
                hoursBelowThreshold: hoursBelowThreshold,
                tariffComparisonRate: tariffComparisonRate,
                todaysCharges: todaysCharges,
                yesterdaysCharges: yesterdaysCharges,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns the charges from [historicalCharges] whose
  /// [HistoricalCharge.validFrom], converted to local time, falls on the same
  /// calendar day as [day].
  List<HistoricalCharge> _getHistoricalChargesOn(
    List<HistoricalCharge> historicalCharges,
    DateTime day,
  ) {
    final result = <HistoricalCharge>[];

    for (final historicalCharge in historicalCharges) {
      if (historicalCharge.validFrom case final validFrom?) {
        if (DateUtils.isSameDay(validFrom.toLocal(), day)) {
          result.add(historicalCharge);
        }
      }
    }

    return result;
  }
}
