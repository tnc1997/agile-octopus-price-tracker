import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';

import '../common/functions.dart';

class HistoricalChargeListTile extends StatelessWidget {
  const HistoricalChargeListTile({
    super.key,
    required this.colorStops,
    required this.historicalCharge,
  });

  /// The color gradient stops used to color the unit rate subtitle by value.
  ///
  /// Passed through [calculatePriceColor] so the number is drawn in the same
  /// color as that price on the chart's gradient line; the slot time title
  /// keeps the default text color.
  final List<(Color, double)> colorStops;

  final HistoricalCharge historicalCharge;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListTile(
      title: Text(
        DateFormat.Hm().format(
          historicalCharge.validFrom!.toLocal(),
        ),
      ),
      subtitle: Text(
        NumberFormat('0.00p/kWh').format(
          historicalCharge.valueIncVat,
        ),
        style: TextStyle(
          color: calculatePriceColor(
            colorStops,
            historicalCharge.valueIncVat,
          ),
        ),
      ),
    );
  }
}
