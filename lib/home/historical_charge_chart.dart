import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../common/num_extensions.dart';
import '../forecast/forecast_service.dart';

class HistoricalChargeChart extends StatefulWidget {
  const HistoricalChargeChart({
    super.key,
    required this.historicalCharges,
  });

  final List<HistoricalCharge> historicalCharges;

  @override
  State<HistoricalChargeChart> createState() {
    return _HistoricalChargeChartState();
  }
}

class _HistoricalChargeChartState extends State<HistoricalChargeChart> {
  /// The color gradient stops used to color each point by its unit rate.
  ///
  /// Loaded once in [initState] from the persisted `color_stops` preference,
  /// falling back to a built-in default when the user has not configured any.
  /// Each entry pairs a color with the price (in pence per kWh) it applies at,
  /// ordered ascending by price, and [_calculateColor] interpolates between
  /// adjacent stops. Held as a [Future] so the chart can show a spinner until the
  /// asynchronous preferences read completes.
  late final Future<List<(Color, double)>> _colorStops;

  /// The shared preferences store, read once from the provider in [initState].
  ///
  /// Source of the persisted `color_stops` gradient and the
  /// `grid_supply_point_group_id` the forecast is built for. Retained so both the
  /// initial color-stop load and the later forecast build can read from the same
  /// instance.
  late final SharedPreferencesAsync _preferences;

  /// The forecast series, built once the forecast service is ready.
  ///
  /// Null until then, so the chart renders the confirmed prices on their own
  /// while the (start-up) table load is still in flight, and gains the forecast
  /// series once it completes. Guarded in [build] so it is built only once.
  Future<List<ForecastCharge>>? _forecastCharges;

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
      future: _colorStops,
      builder: (context, snapshot) {
        if (snapshot.data case final colorStops?) {
          return FutureBuilder(
            future: _forecastCharges,
            builder: (context, snapshot) {
              // Default to an empty series until (or unless) the forecast is
              // ready, so the confirmed prices render without waiting on it.
              final forecastCharges = snapshot.data ?? [];

              return SfCartesianChart(
                primaryXAxis: DateTimeAxis(
                  axisLabelFormatter: (details) {
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      details.value.toInt(),
                    ).toLocal();

                    return ChartAxisLabel(
                      '${DateFormat.Hm().format(date)}\n${DateFormat.EEEE().format(date)}',
                      details.textStyle,
                    );
                  },
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(
                    text: 'Price (p/kWh)',
                  ),
                  numberFormat: NumberFormat('0.00'),
                  plotBands: [
                    PlotBand(
                      start: 0,
                      end: 0,
                      borderColor: Theme.of(context).colorScheme.onSurface,
                      borderWidth: 1,
                    ),
                  ],
                ),
                trackballBehavior: TrackballBehavior(
                  enable: true,
                  builder: (context, details) {
                    return _buildTrackball(details, forecastCharges);
                  },
                ),
                series: [
                  StepLineSeries<HistoricalCharge, DateTime>(
                    dataSource: widget.historicalCharges,
                    xValueMapper: (datum, index) {
                      return datum.validFrom!.toLocal();
                    },
                    yValueMapper: (datum, index) {
                      return datum.valueIncVat;
                    },
                    sortFieldValueMapper: (datum, index) {
                      return datum.validFrom!.toLocal();
                    },
                    pointColorMapper: (datum, index) {
                      return _calculateColor(datum.valueIncVat, colorStops);
                    },
                  ),
                  if (forecastCharges.isNotEmpty)
                    StepLineSeries<ForecastCharge, DateTime>(
                      dataSource: forecastCharges,
                      dashArray: const [6.0, 4.0],
                      xValueMapper: (datum, index) {
                        return datum.validFrom.toLocal();
                      },
                      yValueMapper: (datum, index) {
                        return datum.valueIncVat;
                      },
                      sortFieldValueMapper: (datum, index) {
                        return datum.validFrom.toLocal();
                      },
                      pointColorMapper: (datum, index) {
                        return _calculateColor(datum.valueIncVat, colorStops);
                      },
                    ),
                ],
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

    _preferences = context.read<SharedPreferencesAsync>();

    _colorStops = _preferences.getString('color_stops').then((colorStops) {
      if (colorStops == null) {
        return [
          (Color(0xff2196f3), -1.00),
          (Color(0xff00ff00), 10.00),
          (Color(0xffffff00), 20.00),
          (Color(0xffff0000), 30.00),
        ];
      }

      return (json.decode(colorStops) as List<dynamic>).map((colorStop) {
        return (Color(colorStop['color']), colorStop['price'] as double);
      }).toList();
    });
  }

  /// Builds the tooltip the trackball shows when it settles on a point.
  ///
  /// The chart draws two series — the confirmed prices first and, when there is
  /// one, the forecast second — so [TrackballDetails.seriesIndex] tells which
  /// list the touched point belongs to: index 1 is a [ForecastCharge] from
  /// [forecastCharges], and anything else is a confirmed `HistoricalCharge` from
  /// the widget's `historicalCharges`. Picking the matching list matters because
  /// [TrackballDetails.pointIndex] is relative to its own series, so indexing the
  /// other list would mislabel the point or, where the forecast runs longer than
  /// the confirmed prices, throw a range error. Both charge types carry the same
  /// three values the label needs, which are read into shared locals here.
  ///
  /// The result is a small white rounded card showing the slot's local time
  /// range (`HH:mm - HH:mm`, converted from the stored UTC instants) above the
  /// unit rate formatted to two decimal places in pence per kWh.
  Widget _buildTrackball(
    TrackballDetails details,
    List<ForecastCharge> forecastCharges,
  ) {
    // The forecast is the second series, so a point from it is read off the
    // forecast list; everything else is a confirmed charge. Both expose the same
    // three fields the label needs.
    final DateTime validFrom;
    final DateTime validTo;
    final double valueIncVat;

    if (details.seriesIndex == 1) {
      final datum = forecastCharges[details.pointIndex!];
      validFrom = datum.validFrom;
      validTo = datum.validTo;
      valueIncVat = datum.valueIncVat;
    } else {
      final datum = widget.historicalCharges[details.pointIndex!];
      validFrom = datum.validFrom!;
      validTo = datum.validTo!;
      valueIncVat = datum.valueIncVat;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          '${DateFormat.Hm().format(
            validFrom.toLocal(),
          )} - ${DateFormat.Hm().format(
            validTo.toLocal(),
          )}\n${NumberFormat('0.00p/kWh').format(
            valueIncVat,
          )}',
          style: TextStyle(
            color: Colors.black,
            fontSize: 12.0,
          ),
        ),
      ),
    );
  }

  /// Maps a unit rate to its color by interpolating between the configured
  /// color stops, so a confirmed charge and a forecast charge of the same price
  /// are shown in the same color.
  Color? _calculateColor(
    double value,
    List<(Color, double)> colorStops,
  ) {
    if (value < 0) {
      for (final stop in colorStops) {
        if (stop.$2 < 0) {
          return stop.$1;
        }
      }

      return Color(0xff00ffff);
    }

    for (var i = 0; i < colorStops.length - 1; i++) {
      if (value < colorStops[i].$2) {
        return colorStops[i].$1;
      }

      if (value < colorStops[i + 1].$2) {
        return Color.lerp(
          colorStops[i].$1,
          colorStops[i + 1].$1,
          value.remap(
            colorStops[i].$2,
            colorStops[i + 1].$2,
            0,
            1,
          ),
        );
      }
    }

    return colorStops.last.$1;
  }

  /// Builds the forecast series covering the last published price to seven days
  /// ahead, or an empty series when there is nothing to forecast.
  ///
  /// The forecast continues from the latest confirmed `validTo`, so it picks up
  /// exactly where the published prices end. A failure to reach NESO (or a
  /// missing Grid Supply Point) yields an empty series rather than breaking the
  /// confirmed chart.
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
