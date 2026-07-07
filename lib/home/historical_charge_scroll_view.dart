import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';

import '../forecast/forecast_service.dart';
import 'forecast_charge_list_tile.dart';
import 'historical_charge_list_tile.dart';

class HistoricalChargeScrollView extends StatelessWidget {
  const HistoricalChargeScrollView({
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

    return CustomScrollView(
      slivers: map.entries.map(
        (entry) {
          return SliverMainAxisGroup(
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
          );
        },
      ).toList(),
    );
  }
}
