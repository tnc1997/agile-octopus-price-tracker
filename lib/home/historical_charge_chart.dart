import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../common/num_extensions.dart';
import '../main.dart';

class HistoricalChargeChart extends StatelessWidget {
  static const _stops = [
    (Color(0xff00ff00), 10),
    (Color(0xffffff00), 20),
    (Color(0xffff0000), 30),
  ];

  const HistoricalChargeChart({
    super.key,
    required this.historicalCharges,
  });

  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        title: AxisTitle(
          text: 'Time',
        ),
        dateFormat: DateFormat('Hm'),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(
          text: 'Price (p/kWh)',
        ),
        numberFormat: NumberFormat('0.00'),
      ),
      trackballBehavior: TrackballBehavior(
        enable: true,
      ),
      series: [
        StepLineSeries<HistoricalCharge, DateTime>(
          dataSource: historicalCharges,
          xValueMapper: (datum, index) {
            return datum.validFrom!.toLocal();
          },
          yValueMapper: (datum, index) {
            return datum.valueIncVat!;
          },
          sortFieldValueMapper: (datum, index) {
            return datum.validFrom!.toLocal();
          },
          pointColorMapper: (datum, index) {
            for (var i = 0; i < _stops.length - 1; i++) {
              if (datum.valueIncVat! < _stops[i].$2) {
                return _stops[i].$1;
              }

              if (datum.valueIncVat! < _stops[i + 1].$2) {
                return Color.lerp(
                  _stops[i].$1,
                  _stops[i + 1].$1,
                  datum.valueIncVat!.remap(
                    _stops[i].$2,
                    _stops[i + 1].$2,
                    0,
                    1,
                  ),
                );
              }
            }

            return _stops.last.$1;
          },
        ),
      ],
    );
  }
}
