import 'package:flutter/material.dart';

import '../main.dart';
import 'historical_charge_list_tile.dart';

class HistoricalChargeListView extends StatelessWidget {
  const HistoricalChargeListView({
    super.key,
    required this.historicalCharges,
  });

  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) {
        return HistoricalChargeListTile(
          historicalCharge: historicalCharges[index],
        );
      },
      itemCount: historicalCharges.length,
    );
  }
}
