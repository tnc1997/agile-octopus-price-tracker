import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../main.dart';

class HistoricalChargeChart extends StatelessWidget {
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
      tooltipBehavior: TooltipBehavior(
        enable: true,
        header: '',
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
        ),
      ],
    );
  }
}
