import 'package:flutter/material.dart';

import '../main.dart';
import 'historical_charge_scroll_view.dart';

class HistoricalChargeScrollViewCard extends StatelessWidget {
  const HistoricalChargeScrollViewCard({
    super.key,
    required this.historicalCharges,
  });

  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: HistoricalChargeScrollView(
        historicalCharges: historicalCharges,
      ),
    );
  }
}
