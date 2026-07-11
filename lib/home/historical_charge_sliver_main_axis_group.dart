import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';

import '../forecast/forecast_service.dart';
import 'forecast_charge_list_tile.dart';
import 'historical_charge_list_tile.dart';

/// A lazily-built, day-grouped [SliverMainAxisGroup] of price tiles on a card
/// surface.
///
/// Each day is its own nested [SliverMainAxisGroup] of a [PinnedHeaderSliver]
/// and a [SliverList], so only the tiles near the viewport are built and each
/// day's header stays pinned only for that day's extent. The whole group is
/// wrapped in a [DecoratedSliver] so the surrounding card surface is retained
/// without giving up that laziness — the same decoration pattern the history
/// feature's `HistoricalChargeSliverList` uses. Must be placed among the
/// slivers of a [CustomScrollView].
class HistoricalChargeSliverMainAxisGroup extends StatelessWidget {
  const HistoricalChargeSliverMainAxisGroup({
    super.key,
    required this.colorStops,
    required this.forecastCharges,
    required this.historicalCharges,
  });

  final List<(Color, double)> colorStops;

  final List<ForecastCharge> forecastCharges;

  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    // Merge the confirmed and forecast slots into a single time-ordered list of
    // tiles. Both carry a validFrom used for ordering and grouping; the forecast
    // picks up where the confirmed prices end, so the two do not overlap.
    final tiles = <(DateTime, Widget)>[
      for (final historicalCharge in historicalCharges)
        (
          historicalCharge.validFrom!,
          HistoricalChargeListTile(
            colorStops: colorStops,
            historicalCharge: historicalCharge,
          ),
        ),
      for (final forecastCharge in forecastCharges)
        (
          forecastCharge.validFrom,
          ForecastChargeListTile(
            colorStops: colorStops,
            forecastCharge: forecastCharge,
          ),
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    // Group by calendar day rather than weekday name: the forecast can run a
    // full seven days ahead, so two different dates can share a weekday (e.g.
    // two Mondays a week apart) and grouping by name alone would merge them.
    // The header still shows the weekday, formatted from the day's date.
    final map = groupBy(
      tiles,
      (tile) {
        final date = tile.$1.toLocal();

        return DateTime(date.year, date.month, date.day);
      },
    );

    // Paint the card surface around the whole list with a DecoratedSliver so
    // the rows can stay lazily-built SliverLists; a Card would need a bounded
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
        sliver: SliverMainAxisGroup(
          slivers: [
            for (final entry in map.entries)
              // Each day's header and its rows are their own SliverMainAxisGroup
              // so the header only stays pinned for that day's extent — once
              // its SliverList finishes, the group ends and the header scrolls
              // away with it rather than remaining stacked above the next one.
              SliverMainAxisGroup(
                slivers: [
                  PinnedHeaderSliver(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          DateFormat.EEEE().format(entry.key),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemBuilder: (context, index) {
                      return entry.value[index].$2;
                    },
                    itemCount: entry.value.length,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
