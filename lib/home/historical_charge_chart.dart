import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../common/num_extensions.dart';
import '../main.dart';

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
  late final Future<List<(Color, double)>> _future;

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.data case final stops?) {
          return SfCartesianChart(
            primaryXAxis: DateTimeAxis(
              dateFormat: DateFormat.Hm(),
              crossesAt: 0.0,
            ),
            primaryYAxis: NumericAxis(
              title: AxisTitle(
                text: 'Price (p/kWh)',
              ),
              numberFormat: NumberFormat('0.00'),
            ),
            trackballBehavior: TrackballBehavior(
              enable: true,
              builder: (context, details) {
                final datum = widget.historicalCharges[details.pointIndex!];

                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '${DateFormat.Hm().format(
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
              },
            ),
            series: [
              StepLineSeries<HistoricalCharge, DateTime>(
                dataSource: widget.historicalCharges,
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
                  for (var i = 0; i < stops.length - 1; i++) {
                    if (datum.valueIncVat! < stops[i].$2) {
                      return stops[i].$1;
                    }

                    if (datum.valueIncVat! < stops[i + 1].$2) {
                      return Color.lerp(
                        stops[i].$1,
                        stops[i + 1].$1,
                        datum.valueIncVat!.remap(
                          stops[i].$2,
                          stops[i + 1].$2,
                          0,
                          1,
                        ),
                      );
                    }
                  }

                  return stops.last.$1;
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

    final preferences = context.read<SharedPreferencesAsync>();

    _future = preferences.getString('color_stops').then((stops) {
      if (stops == null) {
        return [
          (Color(0xff00ff00), 10.00),
          (Color(0xffffff00), 20.00),
          (Color(0xffff0000), 30.00),
        ];
      }

      return (json.decode(stops) as List<dynamic>).map((stop) {
        return (Color(stop['color']), stop['price'] as double);
      }).toList();
    });
  }
}
