import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../common/functions.dart';
import '../forecast/forecast_service.dart';

class HistoricalChargeChart extends StatefulWidget {
  const HistoricalChargeChart({
    super.key,
    required this.colorStops,
    required this.forecastCharges,
    required this.historicalCharges,
  });

  final List<(Color, double)> colorStops;

  final List<ForecastCharge> forecastCharges;

  final List<HistoricalCharge> historicalCharges;

  @override
  State<HistoricalChargeChart> createState() {
    return _HistoricalChargeChartState();
  }
}

class _HistoricalChargeChartState extends State<HistoricalChargeChart> {
  @override
  Widget build(
    BuildContext context,
  ) {
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
            return buildPriceGradient(
              widget.colorStops,
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
              return buildPriceGradient(
                widget.colorStops,
                yMinimum,
                yMaximum,
              ).createShader(details.rect);
            },
          ),
      ],
    );
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
}
