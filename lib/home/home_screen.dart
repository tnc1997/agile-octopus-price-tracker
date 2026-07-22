import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/functions.dart';
import '../forecast/forecast_service.dart';
import 'historical_charge_chart_card.dart';
import 'historical_charge_todays_summary_card.dart';
import 'historical_charge_window_wrap.dart';

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
  /// so they color their prices with the same mapping the chart uses, rather
  /// than each small widget performing its own async read. Held as a [Future]
  /// so the content can wait on the asynchronous read, exactly as the chart
  /// does.
  late final Future<List<(Color, double)>> _colorStops;

  /// The threshold, in pence per kilowatt hour, used by the today's summary
  /// card's 'hours below' row.
  ///
  /// Resolved once in [initState] from the persisted
  /// `hours_below_threshold` preference, analogous to
  /// [_tariffComparisonRate]. Distinct from [_colorStops]: the two happen to
  /// default to similar prices, but are independent preferences serving
  /// different purposes.
  late final Future<double> _hoursBelowThreshold;

  /// The tariff comparison rate, in pence per kilowatt hour, used by
  /// the today's summary card's tariff comparison sentence.
  ///
  /// Resolved once in [initState] from the persisted
  /// `tariff_comparison_rate` preference, which is always set by the time
  /// this screen is reachable (see the redirect in `lib/main.dart`),
  /// analogous to [_colorStops].
  late final Future<double> _tariffComparisonRate;

  /// The confirmed unit rates, fetched once in [initState].
  ///
  /// Loads every half-hour slot for the configured import product and tariff
  /// from the Octopus Energy API spanning yesterday's local midnight through
  /// two days ahead of today's — one request wide enough to serve every
  /// consumer on this screen: [HistoricalChargeTodaysSummaryCard] needs the
  /// full yesterday-and-today calendar days (with no partial-day window),
  /// while the Current/Next/Best/Avoid cards, the chart and the forecast
  /// continuation point only want the slots from now onward, derived in
  /// [build] as `upcomingHistoricalCharges`. Sorted ascending by `validFrom`
  /// in [build]. Held as a [Future] so the screen can show a spinner until the
  /// asynchronous fetch completes.
  late final Future<List<HistoricalCharge>> _historicalCharges;

  /// The shared preferences store, read once from the provider in [initState].
  ///
  /// Source of the `grid_supply_point_group_id` the forecast is built for.
  late final SharedPreferencesAsync _preferences;

  /// The forecast charges, built once the forecast service is ready.
  ///
  /// Fetched here and passed down to the chart. Null until the forecast
  /// service is ready and the confirmed prices have loaded, so the chart
  /// renders the confirmed prices on their own until it completes; guarded in
  /// [build] so it is built only once.
  Future<List<ForecastCharge>>? _forecastCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder(
      future: _historicalCharges,
      builder: (context, snapshot) {
        if (snapshot.data case final historicalCharges?) {
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

          final upcomingHistoricalCharges = _getUpcomingHistoricalCharges(
            historicalCharges,
          );

          // The forecast service is null until the lookup table it composes has
          // loaded at start-up, flipping to ready when the load completes. Kick
          // off the forecast the first time it is ready, now the confirmed prices
          // it continues from are available; keeping it to a single build.
          if (context.watch<ForecastService?>() case final forecastService?) {
            _forecastCharges ??= _getForecastCharges(
              forecastService,
              upcomingHistoricalCharges,
            );
          }

          // Wait for the color stops before showing the content so the summary
          // cards render once with their prices already colored, using the same
          // mapping the chart does, rather than redrawing when the asynchronous
          // preferences read completes.
          return FutureBuilder(
            future: (
              _colorStops,
              _hoursBelowThreshold,
              _tariffComparisonRate,
            ).wait,
            builder: (context, snapshot) {
              if (snapshot.data case final data?) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(8.0),
                        sliver: SliverToBoxAdapter(
                          child: HistoricalChargeWindowWrap(
                            colorStops: data.$1,
                            historicalCharges: upcomingHistoricalCharges,
                          ),
                        ),
                      ),
                      FutureBuilder(
                        future: _forecastCharges,
                        builder: (context, snapshot) {
                          // Wait for the forecast to resolve before showing the
                          // chart, so it renders once with the full data rather
                          // than redrawing when the forecast arrives.
                          if (snapshot.data case final forecastCharges?) {
                            return SliverPadding(
                              padding: const EdgeInsets.all(8.0),
                              sliver: SliverToBoxAdapter(
                                child: HistoricalChargeChartCard(
                                  colorStops: data.$1,
                                  forecastCharges: forecastCharges,
                                  historicalCharges: upcomingHistoricalCharges,
                                ),
                              ),
                            );
                          }

                          return const SliverPadding(
                            padding: EdgeInsets.all(8.0),
                            sliver: SliverToBoxAdapter(
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          );
                        },
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(8.0),
                        sliver: SliverToBoxAdapter(
                          child: HistoricalChargeTodaysSummaryCard(
                            colorStops: data.$1,
                            historicalCharges: historicalCharges,
                            hoursBelowThreshold: data.$2,
                            tariffComparisonRate: data.$3,
                          ),
                        ),
                      ),
                    ],
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
    _hoursBelowThreshold = getHoursBelowThreshold(_preferences);
    _tariffComparisonRate = getTariffComparisonRate(_preferences);

    // Both boundaries are built from today's local calendar day components
    // (year/month/day) rather than adding or subtracting a fixed 24-hour
    // Duration from `now`, so a daylight saving transition can't shift either
    // boundary onto the wrong calendar day.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final dayAfterTomorrow = DateTime(today.year, today.month, today.day + 2);

    _historicalCharges = getImportProductCodeAndImportTariffCode(
      client,
      _preferences,
    ).then(
      (value) {
        return client.products.listElectricityTariffStandardUnitRates(
          value.$1,
          value.$2,
          // Three full calendar days of half-hour slots (yesterday, today and
          // tomorrow) is 144, plus a small buffer so a daylight saving
          // fall-back day in the range — 25 hours, i.e. two extra half-hour
          // slots — doesn't get truncated by an exact page size.
          page: 1,
          pageSize: 150,
          periodFrom: yesterday.toUtc(),
          periodTo: dayAfterTomorrow.toUtc(),
        );
      },
    ).then(
      (value) {
        return value.results;
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

    final gsp = await getGridSupplyPointGroupId(_preferences);
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

  /// Returns the charges from [historicalCharges] that haven't finished yet.
  ///
  /// [_historicalCharges] spans yesterday through two days ahead so
  /// [HistoricalChargeTodaysSummaryCard] can see the full calendar day, but
  /// the Current/Next/Best/Avoid cards and the chart still only want the
  /// slots that haven't finished yet — filtering here, once, keeps their
  /// existing 'first slot is always Current' and 'anchor the chart on now'
  /// behavior unchanged, rather than teaching each of them to filter out the
  /// past themselves.
  List<HistoricalCharge> _getUpcomingHistoricalCharges(
    List<HistoricalCharge> historicalCharges,
  ) {
    final now = DateTime.now();

    return historicalCharges.where(
      (historicalCharge) {
        return historicalCharge.validTo?.isAfter(now) == true;
      },
    ).toList();
  }
}
