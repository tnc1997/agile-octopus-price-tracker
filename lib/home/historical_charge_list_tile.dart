import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';

class HistoricalChargeListTile extends StatelessWidget {
  const HistoricalChargeListTile({
    super.key,
    required this.historicalCharge,
  });

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
      ),
    );
  }
}
