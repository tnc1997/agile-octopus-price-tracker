import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';

class HistoricalChargeCard extends StatelessWidget {
  const HistoricalChargeCard({
    super.key,
    required this.historicalCharge,
    this.leading,
    this.trailing,
  });

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
                Text(
                  '${DateFormat.Hm().format(
                    historicalCharge.validFrom!.toLocal(),
                  )} - ${DateFormat.Hm().format(
                    historicalCharge.validTo!.toLocal(),
                  )}',
                ),
                Text(
                  NumberFormat('0.00p/kWh').format(
                    historicalCharge.valueIncVat,
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
