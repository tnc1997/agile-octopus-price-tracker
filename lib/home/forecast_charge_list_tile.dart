import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/functions.dart';
import '../forecast/forecast_service.dart';

class ForecastChargeListTile extends StatelessWidget {
  const ForecastChargeListTile({
    super.key,
    required this.colorStops,
    required this.forecastCharge,
  });

  /// The color gradient stops used to color the unit rate subtitle by value.
  ///
  /// Passed through [calculatePriceColor] so the number is drawn in the same
  /// color as that price on the chart's gradient line; the color is applied
  /// beneath the tile's 0.5 opacity, mirroring how the chart fades the forecast
  /// line rather than dropping its gradient. The slot time title keeps the
  /// default text color.
  final List<(Color, double)> colorStops;

  final ForecastCharge forecastCharge;

  @override
  Widget build(
    BuildContext context,
  ) {
    // Fade the tile so the forecast reads as an estimate rather than a
    // confirmed Agile Octopus rate, mirroring the forecast line.
    return Opacity(
      opacity: 0.5,
      child: ListTile(
        title: Text(
          DateFormat.Hm().format(
            forecastCharge.validFrom.toLocal(),
          ),
        ),
        subtitle: Text(
          NumberFormat('0.00p/kWh').format(
            forecastCharge.valueIncVat,
          ),
          style: TextStyle(
            color: calculatePriceColor(
              colorStops,
              forecastCharge.valueIncVat,
            ),
          ),
        ),
      ),
    );
  }
}
