import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/functions.dart';
import '../forecast/forecast_service.dart';
import 'historical_charge_chart_card.dart';
import 'historical_charge_scroll_view_card.dart';
import 'historical_charge_summary_sliver_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  /// The color gradient stops used to color each textual charge by its unit
  /// rate.
  ///
  /// Resolved once in [initState] from the persisted `color_stops` preference
  /// (falling back to a built-in default) and handed down to the summary cards
  /// and list tiles so they color their prices with the same mapping the chart
  /// uses, rather than each small widget performing its own async read. Held as
  /// a [Future] so the content can wait on the asynchronous read, exactly as the
  /// chart does.
  late final Future<List<(Color, double)>> _colorStops;

  /// The confirmed unit rates, fetched once in [initState].
  ///
  /// Loads the next 96 half-hour slots (two days) for the configured import
  /// product and tariff from the Octopus Energy API, starting at the current
  /// instant. Sorted ascending by `validFrom` in [build] and passed down to the
  /// summary cards, chart and list, and used as the point the forecast
  /// continues from. Held as a [Future] so the screen can show a spinner until
  /// the asynchronous fetch completes.
  late final Future<PaginatedHistoricalChargeList> _historicalCharges;

  /// The shared preferences store, read once from the provider in [initState].
  ///
  /// Source of the `grid_supply_point_group_id` the forecast is built for.
  late final SharedPreferencesAsync _preferences;

  /// The forecast charges, built once the forecast service is ready.
  ///
  /// Fetched here and passed down to both the chart and the list, so the two
  /// share a single forecast rather than each fetching their own. Null until the
  /// forecast service is ready and the confirmed prices have loaded, so those
  /// views render the confirmed prices on their own until it completes; guarded
  /// in [build] so it is built only once.
  Future<List<ForecastCharge>>? _forecastCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder(
      future: _historicalCharges,
      builder: (context, snapshot) {
        if (snapshot.data?.results case final historicalCharges?) {
          historicalCharges.sort(
            (a, b) {
              if (a.validFrom case final a?) {
                if (b.validFrom case final b?) {
                  return a.compareTo(b);
                }
              }

              return 0;
            },
          );

          // The forecast service is null until the lookup table it composes has
          // loaded at start-up, flipping to ready when the load completes. Kick
          // off the forecast the first time it is ready, now the confirmed prices
          // it continues from are available; keeping it to a single build.
          if (context.watch<ForecastService?>() case final forecastService?) {
            _forecastCharges ??= _getForecastCharges(
              forecastService,
              historicalCharges,
            );
          }

          // Wait for the color stops before showing the content so the summary
          // cards and list tiles render once with their prices already colored,
          // using the same mapping the chart does, rather than redrawing when
          // the asynchronous preferences read completes.
          return FutureBuilder(
            future: _colorStops,
            builder: (context, snapshot) {
              if (snapshot.data case final colorStops?) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(8.0),
                            sliver: HistoricalChargeSummarySliverGrid(
                              colorStops: colorStops,
                              historicalCharges: historicalCharges,
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.all(8.0),
                            sliver: SliverGrid(
                              delegate: SliverChildListDelegate.fixed(
                                [
                                  FutureBuilder(
                                    future: _forecastCharges,
                                    builder: (context, snapshot) {
                                      // Wait for the forecast to resolve before showing
                                      // the chart, so it renders once with the full data
                                      // rather than redrawing when the forecast arrives.
                                      if (snapshot.data
                                          case final forecastCharges?) {
                                        return HistoricalChargeChartCard(
                                          colorStops: colorStops,
                                          forecastCharges: forecastCharges,
                                          historicalCharges: historicalCharges,
                                        );
                                      }

                                      return const Card(
                                        margin: EdgeInsets.zero,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                  ),
                                  FutureBuilder(
                                    future: _forecastCharges,
                                    builder: (context, snapshot) {
                                      // Likewise wait for the forecast before showing
                                      // the list, so its rows are complete rather
                                      // than growing when the forecast arrives.
                                      if (snapshot.data
                                          case final forecastCharges?) {
                                        return HistoricalChargeScrollViewCard(
                                          colorStops: colorStops,
                                          forecastCharges: forecastCharges,
                                          historicalCharges: historicalCharges,
                                        );
                                      }

                                      return const Card(
                                        margin: EdgeInsets.zero,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    constraints.maxWidth > 768 ? 2 : 1,
                                mainAxisSpacing: 16.0,
                                crossAxisSpacing: 16.0,
                                childAspectRatio: 1.0,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }

              return Center(
                child: CircularProgressIndicator(),
              );
            },
          );
        }

        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    final client = context.read<OctopusEnergyApiClient>();
    _preferences = context.read<SharedPreferencesAsync>();

    _colorStops = getColorStops(_preferences);

    _historicalCharges = (
      _preferences.getString('import_product_code'),
      _preferences.getString('import_tariff_code'),
    ).wait.then(
      (value) {
        return client.products.listElectricityTariffStandardUnitRates(
          value.$1!,
          value.$2!,
          page: 1,
          pageSize: 96,
          periodFrom: DateTime.now().toUtc(),
        );
      },
    );
  }

  /// Builds the forecast charges covering the last published price to seven days
  /// ahead, or none when there is nothing to forecast.
  ///
  /// The forecast continues from the latest confirmed `validTo`, so it picks up
  /// exactly where the published prices end. A failure to reach NESO (or a
  /// missing Grid Supply Point) yields no forecast rather than breaking the
  /// confirmed prices.
  Future<List<ForecastCharge>> _getForecastCharges(
    ForecastService forecastService,
    List<HistoricalCharge> historicalCharges,
  ) async {
    // The forecast begins where the published prices end: the latest validTo.
    DateTime? from;
    for (final historicalCharge in historicalCharges) {
      if (historicalCharge.validTo case final validTo?) {
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
      return await forecastService.getForecastCharges(
        gsp: gsp,
        from: from,
        to: to,
      );
    } catch (_) {
      return const [];
    }
  }
}
