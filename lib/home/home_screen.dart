import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../forecast/forecast_service.dart';
import 'historical_charge_card.dart';
import 'historical_charge_chart_card.dart';
import 'historical_charge_scroll_view_card.dart';

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
  late final Future<PaginatedHistoricalChargeList> _future;

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
      future: _future,
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

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(8.0),
                      sliver: SliverGrid(
                        delegate: SliverChildListDelegate.fixed(
                          [
                            HistoricalChargeCard(
                              historicalCharge: historicalCharges[0],
                              leading: Tooltip(
                                message: 'Current',
                                child: Icon(Icons.circle_outlined),
                              ),
                            ),
                            HistoricalChargeCard(
                              historicalCharge: historicalCharges[1],
                              leading: Tooltip(
                                message: 'Next',
                                child: Icon(Icons.arrow_circle_right_outlined),
                              ),
                            ),
                            HistoricalChargeCard(
                              historicalCharge: minBy<HistoricalCharge, double>(
                                historicalCharges,
                                (historicalCharge) {
                                  return historicalCharge.valueIncVat;
                                },
                              )!,
                              leading: Tooltip(
                                message: 'Lowest',
                                child: Icon(Icons.arrow_circle_down_outlined),
                              ),
                            ),
                            HistoricalChargeCard(
                              historicalCharge: maxBy<HistoricalCharge, double>(
                                historicalCharges,
                                (historicalCharge) {
                                  return historicalCharge.valueIncVat;
                                },
                              )!,
                              leading: Tooltip(
                                message: 'Highest',
                                child: Icon(Icons.arrow_circle_up_outlined),
                              ),
                            ),
                          ],
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth > 768 ? 4 : 2,
                          mainAxisSpacing: 16.0,
                          crossAxisSpacing: 16.0,
                          childAspectRatio: 2.0,
                        ),
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
                                if (snapshot.data case final forecastCharges?) {
                                  return HistoricalChargeChartCard(
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
                                if (snapshot.data case final forecastCharges?) {
                                  return HistoricalChargeScrollViewCard(
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
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth > 768 ? 2 : 1,
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

  @override
  void initState() {
    super.initState();

    final client = context.read<OctopusEnergyApiClient>();
    _preferences = context.read<SharedPreferencesAsync>();

    _future = (
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
