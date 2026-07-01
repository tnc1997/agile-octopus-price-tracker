import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../forecast/forecast_service.dart';
import 'forecast_charge_list_tile.dart';
import 'historical_charge_list_tile.dart';

class HistoricalChargeScrollView extends StatefulWidget {
  const HistoricalChargeScrollView({
    super.key,
    required this.historicalCharges,
  });

  final List<HistoricalCharge> historicalCharges;

  @override
  State<HistoricalChargeScrollView> createState() {
    return _HistoricalChargeScrollViewState();
  }
}

class _HistoricalChargeScrollViewState
    extends State<HistoricalChargeScrollView> {
  /// The forecast charges, built once the forecast service is ready.
  ///
  /// Null until then, so the list renders the confirmed prices on their own
  /// while the (start-up) table load is still in flight, and gains the forecast
  /// slots once it completes. Guarded in [build] so it is built only once.
  Future<List<ForecastCharge>>? _forecastCharges;

  /// The shared preferences store, read once from the provider in [initState].
  ///
  /// Source of the persisted `grid_supply_point_group_id` the forecast is built
  /// for.
  late final SharedPreferencesAsync _preferences;

  @override
  Widget build(
    BuildContext context,
  ) {
    // The forecast service is null until the lookup table it composes has
    // loaded at start-up, flipping to ready when the load completes. Kick off
    // the forecast the first time it is ready; keeping it to a single build.
    if (context.watch<ForecastService?>() case final service?) {
      _forecastCharges ??= _getForecastCharges(service);
    }

    return FutureBuilder(
      future: _forecastCharges,
      builder: (context, snapshot) {
        // Default to no forecast until (or unless) it is ready, so the confirmed
        // prices render without waiting on it.
        final forecastCharges = snapshot.data ?? [];

        // Merge the confirmed and forecast slots into a single time-ordered list
        // of tiles. Both carry a validFrom used for ordering and grouping; the
        // forecast picks up where the confirmed prices end, so the two do not
        // overlap.
        final tiles = <(DateTime, Widget)>[
          for (final historicalCharge in widget.historicalCharges)
            (
              historicalCharge.validFrom!,
              HistoricalChargeListTile(
                historicalCharge: historicalCharge,
              ),
            ),
          for (final forecastCharge in forecastCharges)
            (
              forecastCharge.validFrom,
              ForecastChargeListTile(
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
      },
    );
  }

  @override
  void initState() {
    super.initState();

    _preferences = context.read<SharedPreferencesAsync>();
  }

  /// Builds the forecast charges covering the last published price to seven days
  /// ahead, or none when there is nothing to forecast.
  ///
  /// The forecast continues from the latest confirmed `validTo`, so it picks up
  /// exactly where the published prices end. A failure to reach NESO (or a
  /// missing Grid Supply Point) yields no forecast rather than breaking the
  /// confirmed list.
  Future<List<ForecastCharge>> _getForecastCharges(
    ForecastService service,
  ) async {
    // The forecast begins where the published prices end: the latest validTo.
    DateTime? from;
    for (final charge in widget.historicalCharges) {
      if (charge.validTo case final validTo?) {
        if (from == null || validTo.isAfter(from)) {
          from = validTo;
        }
      }
    }
    if (from == null) {
      return const [];
    }

    final gsp = await _preferences.getString('grid_supply_point_group_id');
    if (gsp == null) {
      return const [];
    }

    final to = DateTime.now().toUtc().add(const Duration(days: 7));
    if (!from.isBefore(to)) {
      return const [];
    }

    try {
      return await service.getForecastCharges(
        gsp: gsp,
        from: from,
        to: to,
      );
    } catch (_) {
      return const [];
    }
  }
}
