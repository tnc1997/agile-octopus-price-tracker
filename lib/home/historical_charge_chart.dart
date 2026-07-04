import 'dart:convert';

import 'package:collection/collection.dart';
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
    required this.forecastCharges,
    required this.historicalCharges,
  });

  final List<ForecastCharge> forecastCharges;

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
  /// Source of the persisted `color_stops` gradient.
  late final SharedPreferencesAsync _preferences;

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder(
      future: _colorStops,
      builder: (context, snapshot) {
        if (snapshot.data case final colorStops?) {
          // Derive the axis extent from the data: the earliest slot start to the
          // latest slot end, spanning both the confirmed prices and the forecast
          // (the parent renders the chart only once the forecast has resolved).
          // The bounds use the same local instants the series plot against, and
          // are null when there is no data at all, leaving the axis to fall back
          // to auto-ranging.
          final bounds = <DateTime>[
            for (final historicalCharge in widget.historicalCharges) ...[
              historicalCharge.validFrom!.toLocal(),
              historicalCharge.validTo!.toLocal(),
            ],
            for (final forecastCharge in widget.forecastCharges) ...[
              forecastCharge.validFrom.toLocal(),
              forecastCharge.validTo.toLocal(),
            ],
          ];

          final xMinimum = bounds.minOrNull;
          final xMaximum = bounds.maxOrNull;

          // Fix the price axis to the data extent so the gradient can map price
          // to a pixel position: the shader spans the plot area, and pinning the
          // axis makes its bottom edge [yMinimum] and top edge [yMaximum].
          final values = <double>[
            for (final historicalCharge in widget.historicalCharges)
              historicalCharge.valueIncVat,
            for (final forecastCharge in widget.forecastCharges)
              forecastCharge.valueIncVat,
          ];

          final yMinimum = values.minOrNull?.floorToDouble() ?? 0;
          final yMaximum = values.maxOrNull?.ceilToDouble() ?? 0;

          return SfCartesianChart(
            primaryXAxis: DateTimeAxis(
              minimum: xMinimum,
              maximum: xMaximum,
              initialVisibleMinimum: xMinimum,
              // Open on a day-ahead window from the first slot — the current
              // and upcoming confirmed prices plus the start of the forecast —
              // rather than the whole week at once. Anchoring on the first
              // slot start keeps the current slot flush to the left edge;
              // users can pan or zoom out to the derived extent.
              initialVisibleMaximum: xMinimum?.add(
                const Duration(
                  days: 1,
                ),
              ),
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
              minimum: yMinimum,
              maximum: yMaximum,
              plotBands: [
                PlotBand(
                  start: 0,
                  end: 0,
                  borderColor: Theme.of(context).colorScheme.onSurface,
                  borderWidth: 1,
                ),
              ],
            ),
            zoomPanBehavior: ZoomPanBehavior(
              enablePinching: true,
              enableDoubleTapZooming: true,
              enablePanning: true,
              enableMouseWheelZooming: true,
              zoomMode: ZoomMode.x,
            ),
            trackballBehavior: TrackballBehavior(
              enable: true,
              builder: (context, details) {
                return _buildTrackball(details);
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
                // Color the whole line by price with a vertical gradient rather
                // than per-point, so the vertical riser between two slots is
                // painted the color of the price it moves through instead of
                // inheriting the previous slot's color (see issue #32).
                onCreateShader: (details) {
                  return _buildGradient(
                    colorStops,
                    yMinimum,
                    yMaximum,
                  ).createShader(details.rect);
                },
              ),
              if (widget.forecastCharges.isNotEmpty)
                StepLineSeries<ForecastCharge, DateTime>(
                  dataSource: widget.forecastCharges,
                  // Dash and fade the line so the forecast reads as an
                  // estimate rather than a confirmed Agile Octopus rate.
                  dashArray: const [6.0, 4.0],
                  opacity: 0.5,
                  xValueMapper: (datum, index) {
                    return datum.validFrom.toLocal();
                  },
                  yValueMapper: (datum, index) {
                    return datum.valueIncVat;
                  },
                  sortFieldValueMapper: (datum, index) {
                    return datum.validFrom.toLocal();
                  },
                  // Color the whole line by price with a vertical gradient rather
                  // than per-point, so the vertical riser between two slots is
                  // painted the color of the price it moves through instead of
                  // inheriting the previous slot's color (see issue #32).
                  onCreateShader: (details) {
                    return _buildGradient(
                      colorStops,
                      yMinimum,
                      yMaximum,
                    ).createShader(details.rect);
                  },
                ),
            ],
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
  /// list the touched point belongs to: index 1 is a [ForecastCharge] from the
  /// widget's `forecastCharges`, and anything else is a confirmed
  /// `HistoricalCharge` from its `historicalCharges`. Picking the matching list
  /// matters because [TrackballDetails.pointIndex] is relative to its own series,
  /// so indexing the other list would mislabel the point or, where the forecast
  /// runs longer than the confirmed prices, throw a range error. Both charge
  /// types carry the same three values the label needs, which are read into
  /// shared locals here.
  ///
  /// The result is a small white rounded card showing the slot's local time
  /// range (`HH:mm - HH:mm`, converted from the stored UTC instants) above the
  /// unit rate formatted to two decimal places in pence per kWh.
  Widget _buildTrackball(
    TrackballDetails details,
  ) {
    // The forecast is the second series, so a point from it is read off the
    // forecast list; everything else is a confirmed charge. Both expose the same
    // three fields the label needs.
    final DateTime validFrom;
    final DateTime validTo;
    final double valueIncVat;

    if (details.seriesIndex == 1) {
      final datum = widget.forecastCharges[details.pointIndex!];
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

  /// Builds the vertical gradient used to color a series by price.
  ///
  /// The series' `onCreateShader` paints every segment — including the vertical
  /// riser between two slots — with this shader stretched across the whole plot
  /// area, so each pixel is colored by its position rather than by the color of
  /// the point that owns the segment (which left risers overflowing their band;
  /// see issue #32). Because the price axis is pinned to [minimum]..[maximum]
  /// with no range padding, a pixel's vertical position is its price: the bottom
  /// edge is [minimum] and the top edge is [maximum].
  ///
  /// The colors are sampled from [_calculateColor] evenly across that range so
  /// the gradient tracks the configured color stops.
  LinearGradient _buildGradient(
    List<(Color, double)> colorStops,
    double minimum,
    double maximum,
  ) {
    // The gradient is defined by sampling [_calculateColor] at a fixed number
    // of prices and letting Flutter interpolate between the samples. The math
    // that lines each sample up with the price it represents:
    //
    // Flutter spaces a gradient's colors evenly when no explicit `stops` are
    // given — with N colors, color i sits at fraction i / (N - 1) along the
    // gradient, so color 0 is at fraction 0.0 and color N - 1 is at 1.0. With
    // `begin: bottomCenter` and `end: topCenter` the gradient runs bottom to
    // top, so fraction 0.0 is the plot area's bottom edge and 1.0 its top edge.
    // Because the price axis is pinned to [minimum]..[maximum] (see the doc
    // comment), those edges are the prices [minimum] and [maximum].
    //
    // A point at fraction t up the plot area therefore represents the price
    //
    //     price(t) = minimum + t * (maximum - minimum),
    //
    // a linear map from the unit interval [0, 1] onto [minimum, maximum]. To
    // give sample i the right color we evaluate that map at the sample's own
    // fraction, t = i / (N - 1):
    //
    //     price_i = minimum + (maximum - minimum) * i / (N - 1),
    //
    // which is the value handed to [_calculateColor] below. The endpoints fall
    // exactly on the range: i = 0 yields [minimum] and i = N - 1 yields
    // [maximum]. Dividing by N - 1 rather than N is what places the last sample
    // on the top edge instead of one step short of it — there are N samples but
    // only N - 1 gaps between them.
    //
    // Flutter interpolates linearly between adjacent samples. [_calculateColor]
    // is itself piecewise-linear in price, so the only deviation is the tiny
    // chord-versus-line gap where a color stop falls between two samples; at
    // N = 64 across a realistic price range each gap spans well under a pixel,
    // so it is not visible.
    const samples = 64;

    final colors = <Color>[];

    for (var i = 0; i < samples; i++) {
      final value = minimum + (maximum - minimum) * i / (samples - 1);

      if (_calculateColor(colorStops, value) case final color?) {
        colors.add(color);
      } else {
        colors.add(Colors.transparent);
      }
    }

    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: colors,
    );
  }

  /// Maps a unit rate to its color by interpolating between the configured
  /// color stops, so a confirmed charge and a forecast charge of the same price
  /// are shown in the same color.
  Color? _calculateColor(
    List<(Color, double)> colorStops,
    double value,
  ) {
    if (value < 0) {
      for (final colorStop in colorStops) {
        if (colorStop.$2 < 0) {
          return colorStop.$1;
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
}
