import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';

import '../common/functions.dart';

class HistoricalChargeCard extends StatelessWidget {
  const HistoricalChargeCard({
    super.key,
    required this.colorStops,
    required this.historicalCharge,
    this.leading,
    this.trailing,
  });

  /// The color gradient stops used to color the price value by its unit rate.
  ///
  /// Passed through [calculatePriceColor] so the number is drawn in the same
  /// color as that price on the chart's gradient line; the time range and icons
  /// keep the default text color.
  final List<(Color, double)> colorStops;

  final HistoricalCharge historicalCharge;

  final Widget? leading;

  final Widget? trailing;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading case final leading?) leading,
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: leading != null && trailing != null
                  ? CrossAxisAlignment.center
                  : leading != null
                      ? CrossAxisAlignment.end
                      : trailing != null
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: DateFormat.yMMMMEEEEd().format(
                    historicalCharge.validFrom!.toLocal(),
                  ),
                  child: Text(
                    '${DateFormat.Hm().format(
                      historicalCharge.validFrom!.toLocal(),
                    )} - ${DateFormat.Hm().format(
                      historicalCharge.validTo!.toLocal(),
                    )}',
                  ),
                ),
                Text(
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
              ],
            ),
            if (trailing case final trailing?) trailing,
          ],
        ),
      ),
    );
  }
}
