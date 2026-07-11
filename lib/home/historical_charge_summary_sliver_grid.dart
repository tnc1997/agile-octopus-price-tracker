import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';

import '../common/functions.dart';
import 'historical_charge_summary_card.dart';

class HistoricalChargeSummarySliverGrid extends StatelessWidget {
  const HistoricalChargeSummarySliverGrid({
    super.key,
    required this.colorStops,
    required this.historicalCharges,
  });

  final List<(Color, double)> colorStops;

  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    // The 'Best' and 'Avoid' cards look only at the slots remaining today —
    // from now to midnight — so they never recommend or warn about a period
    // that has already passed or falls on a later day. The 'Current' and
    // 'Next' cards, in contrast, always come from the first two slots and so
    // keep reading from the full list (e.g. 'Next' rolls into tomorrow's first
    // slot late in the day).
    final remaining = _getHistoricalChargesEndingOn(
      historicalCharges,
      _getTomorrow(),
    );

    final min = findCheapestWindow(
      remaining,
      const Duration(
        hours: 2,
      ),
    );

    final max = maxBy(
      remaining,
      (historicalCharge) {
        return historicalCharge.valueIncVat;
      },
    );

    return SliverGrid(
      delegate: SliverChildListDelegate.fixed(
        [
          if (historicalCharges.isNotEmpty)
            HistoricalChargeSummaryCard(
              colorStops: colorStops,
              label: 'Current',
              sublabel: '${DateFormat.Hm().format(
                historicalCharges[0].validFrom!.toLocal(),
              )} - ${DateFormat.Hm().format(
                historicalCharges[0].validTo!.toLocal(),
              )}',
              value: historicalCharges[0].valueIncVat,
            ),
          if (historicalCharges.length > 1)
            HistoricalChargeSummaryCard(
              colorStops: colorStops,
              label: 'Next',
              sublabel: '${DateFormat.Hm().format(
                historicalCharges[1].validFrom!.toLocal(),
              )} - ${DateFormat.Hm().format(
                historicalCharges[1].validTo!.toLocal(),
              )}',
              value: historicalCharges[1].valueIncVat,
            ),
          if (min != null)
            HistoricalChargeSummaryCard(
              colorStops: colorStops,
              label: 'Best',
              prefix: 'avg',
              sublabel: '${DateFormat.Hm().format(
                min.$1.first.validFrom!.toLocal(),
              )} - ${DateFormat.Hm().format(
                min.$1.last.validTo!.toLocal(),
              )}',
              value: min.$2,
            ),
          if (max != null)
            HistoricalChargeSummaryCard(
              colorStops: colorStops,
              label: 'Avoid',
              sublabel: '${DateFormat.Hm().format(
                max.validFrom!.toLocal(),
              )} - ${DateFormat.Hm().format(
                max.validTo!.toLocal(),
              )}',
              value: max.valueIncVat,
            )
        ],
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 768 ? 4 : 2,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        childAspectRatio: 2.0,
      ),
    );
  }

  /// Returns the charges from [historicalCharges] that are valid up to and
  /// including [end].
  ///
  /// A charge is included only if both its [HistoricalCharge.validFrom] and
  /// [HistoricalCharge.validTo] are non-null and fall on or before [end] —
  /// charges that start after [end], extend beyond it, or have either bound
  /// missing are excluded. The comparison is inclusive, so a charge whose
  /// [HistoricalCharge.validTo] is exactly equal to [end] is included.
  ///
  /// The returned list preserves the relative order of [historicalCharges]
  /// and does not mutate it.
  List<HistoricalCharge> _getHistoricalChargesEndingOn(
    List<HistoricalCharge> historicalCharges,
    DateTime end,
  ) {
    final result = <HistoricalCharge>[];

    for (final historicalCharge in historicalCharges) {
      if (historicalCharge.validFrom case final validFrom?) {
        if (validFrom.compareTo(end) <= 0) {
          if (historicalCharge.validTo case final validTo?) {
            if (validTo.compareTo(end) <= 0) {
              result.add(historicalCharge);
            }
          }
        }
      }
    }

    return result;
  }

  /// Returns tomorrow's date, normalized to midnight local time.
  ///
  /// Adds a single day to the current local [DateTime.now] and then discards
  /// the time-of-day components by reconstructing a [DateTime] from just the
  /// year, month, and day. Because the day is added before truncation, this
  /// rolls over correctly across month and year boundaries and respects the
  /// local time zone rather than simply adding 24 hours in UTC.
  ///
  /// Used as the cutoff when scoping the summary cards to the slots remaining
  /// today, keeping only those whose `validFrom` and `validTo` fall on or
  /// before this instant. The returned value is local time, but the
  /// comparisons are unaffected by that since [DateTime.compareTo] compares the
  /// underlying instant regardless of each operand's time zone.
  DateTime _getTomorrow() {
    final now = DateTime.now().add(
      const Duration(
        days: 1,
      ),
    );

    return DateTime(now.year, now.month, now.day);
  }
}
