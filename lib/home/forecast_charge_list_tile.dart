import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../forecast/forecast_service.dart';

class ForecastChargeListTile extends StatelessWidget {
  const ForecastChargeListTile({
    super.key,
    required this.forecastCharge,
  });

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
        ),
      ),
    );
  }
}
