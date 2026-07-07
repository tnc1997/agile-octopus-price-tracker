import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../common/functions.dart';

class HistoricalChargeChart extends StatefulWidget {
  const HistoricalChargeChart({
    super.key,
    required this.colorStops,
    required this.historicalCharges,
  });

  /// The color gradient stops used to color the line by its unit rate.
  ///
  /// Resolved once by the history screen and handed down so the chart and the
  /// textual charges share a single source of truth; [buildPriceGradient]
  /// samples [calculatePriceColor] across these stops to paint the step line.
  final List<(Color, double)> colorStops;

  /// The confirmed unit rates to plot as a step line.
  ///
  /// Expected in ascending `validFrom` order; each point is drawn as a step
  /// held from its `validFrom` to the next slot. The axis extent and the price
  /// gradient are both derived from these values, so an empty list yields an
  /// empty, auto-ranged chart.
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
    // latest slot end. The bounds use the same local instants the series plots
    // against, and are null when there is no data at all, leaving the axis to
    // fall back to auto-ranging.
    final bounds = <DateTime>[
      for (final historicalCharge in widget.historicalCharges) ...[
        historicalCharge.validFrom!.toLocal(),
        historicalCharge.validTo!.toLocal(),
      ],
    ];

    final xMinimum = bounds.minOrNull;
    final xMaximum = bounds.maxOrNull;

    // Fix the price axis to the data extent so the gradient can map price to a
    // pixel position: the shader spans the plot area, and pinning the axis
    // makes its bottom edge [yMinimum] and top edge [yMaximum].
    final values = <double>[
      for (final historicalCharge in widget.historicalCharges)
        historicalCharge.valueIncVat,
    ];

    final yMinimum = values.minOrNull?.floorToDouble() ?? 0;
    final yMaximum = values.maxOrNull?.ceilToDouble() ?? 0;

    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        minimum: xMinimum,
        maximum: xMaximum,
        axisLabelFormatter: (details) {
          final date = DateTime.fromMillisecondsSinceEpoch(
            details.value.toInt(),
          ).toLocal();

          return ChartAxisLabel(
            '${DateFormat.MMMMd().format(date)}\n${DateFormat.EEEE().format(date)}',
            details.textStyle,
          );
        },
      ),
      primaryYAxis: NumericAxis(
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
          // Color the whole line by price with a vertical gradient rather than
          // per-point, so the vertical riser between two slots is painted the
          // color of the price it moves through instead of inheriting the
          // previous slot's color (see issue #32).
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
  /// The history chart draws a single series, so the touched point is always a
  /// confirmed charge read off `historicalCharges` by
  /// [TrackballDetails.pointIndex]. The card shows the slot's local date and
  /// time range above the unit rate in pence per kWh; the date matters here
  /// because the range can span many days.
  Widget _buildTrackball(
    TrackballDetails details,
  ) {
    final datum = widget.historicalCharges[details.pointIndex!];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          '${DateFormat.MMMMEEEEd().format(
            datum.validFrom!.toLocal(),
          )}\n${DateFormat.Hm().format(
            datum.validFrom!.toLocal(),
          )} - ${DateFormat.Hm().format(
            datum.validTo!.toLocal(),
          )}\n${NumberFormat('0.00p/kWh').format(
            datum.valueIncVat,
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
