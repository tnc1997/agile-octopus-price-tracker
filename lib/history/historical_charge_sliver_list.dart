import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';

/// A lazily-built list of per-day charge summaries on a card surface.
///
/// The rows are a [SliverList] so only the visible days are built — a wide
/// custom range can cover thousands of days, and an eager column would build
/// them all up front — wrapped in a [DecoratedSliver] so the surrounding card
/// surface is retained without giving up that laziness. Must be placed among
/// the slivers of a [CustomScrollView].
class HistoricalChargeSliverList extends StatelessWidget {
  const HistoricalChargeSliverList({
    super.key,
    required this.historicalCharges,
  });

  /// The charges summarized per calendar day.
  ///
  /// Must not be empty; the history screen shows an empty state instead when
  /// there are no charges for the selected range.
  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    // Group by calendar day rather than weekday name: a range can run longer
    // than a week, so two different dates can share a weekday (e.g. two Mondays
    // a week apart) and grouping by name alone would merge them. The charges
    // arrive sorted ascending by validFrom, so the days come out in order.
    final summaries = groupBy(
      historicalCharges,
      (historicalCharge) {
        // Group by local calendar day: validFrom is a UTC instant, so keying
        // off its UTC components would shift the day boundary by the local
        // offset (e.g. during BST), splitting midnight-adjacent slots into the
        // wrong day and disagreeing with the chart's local-time axis.
        final validFrom = historicalCharge.validFrom!.toLocal();

        return DateTime(validFrom.year, validFrom.month, validFrom.day);
      },
    ).entries.toList();

    // Paint the card surface around the whole list with a DecoratedSliver so
    // the rows can stay a lazily-built SliverList; a Card would need a bounded
    // height (and so build every row) to enclose them. The surface color,
    // border radius and shadow mirror the Material 3 Card the other sections
    // use — kElevationToShadow[1] is Flutter's BoxShadow approximation of the
    // elevation-1 shadow a Card draws by default.
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: kElevationToShadow[1],
      ),
      sliver: SliverPadding(
        padding: const EdgeInsets.all(16.0),
        sliver: SliverList.separated(
          itemBuilder: (context, index) {
            return _DailyHistoricalChargeSummaryRow(
              date: summaries[index].key,
              historicalCharges: summaries[index].value,
            );
          },
          separatorBuilder: (context, index) {
            return const Divider();
          },
          itemCount: summaries.length,
        ),
      ),
    );
  }
}

class _DailyHistoricalChargeSummaryRow extends StatelessWidget {
  const _DailyHistoricalChargeSummaryRow({
    required this.date,
    required this.historicalCharges,
  });

  /// The local calendar day this row summarizes, shown as the row's heading.
  final DateTime date;

  /// The charges whose slots fall on [date].
  ///
  /// Reduced in [build] to the day's average, lowest and highest unit rate;
  /// grouping guarantees at least one charge, so the reduction is well-defined.
  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    var sum = 0.0;
    var min = double.infinity;
    var max = double.negativeInfinity;
    var length = 0;

    for (final historicalCharge in historicalCharges) {
      sum += historicalCharge.valueIncVat;

      if (historicalCharge.valueIncVat < min) {
        min = historicalCharge.valueIncVat;
      }

      if (historicalCharge.valueIncVat > max) {
        max = historicalCharge.valueIncVat;
      }

      length++;
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _DailyHistoricalChargeSummaryColumn(
            label: DateFormat.EEEE().format(date),
            value: DateFormat.MMMMd().format(date),
          ),
        ),
        Expanded(
          flex: 2,
          child: _DailyHistoricalChargeSummaryColumn(
            label: 'Average',
            value: NumberFormat('0.00').format(sum / length),
          ),
        ),
        Expanded(
          flex: 2,
          child: _DailyHistoricalChargeSummaryColumn(
            label: 'Lowest',
            value: NumberFormat('0.00').format(min),
          ),
        ),
        Expanded(
          flex: 2,
          child: _DailyHistoricalChargeSummaryColumn(
            label: 'Highest',
            value: NumberFormat('0.00').format(max),
          ),
        ),
      ],
    );
  }
}

class _DailyHistoricalChargeSummaryColumn extends StatelessWidget {
  const _DailyHistoricalChargeSummaryColumn({
    required this.label,
    required this.value,
  });

  /// The caption shown above the value (a column heading or the weekday).
  final String label;

  /// The pre-formatted text shown beneath the [label].
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
