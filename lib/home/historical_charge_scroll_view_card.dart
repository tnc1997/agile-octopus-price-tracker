import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';

import '../forecast/forecast_service.dart';
import 'historical_charge_scroll_view.dart';

class HistoricalChargeScrollViewCard extends StatelessWidget {
  const HistoricalChargeScrollViewCard({
    super.key,
    required this.forecastCharges,
    required this.historicalCharges,
  });

  final List<ForecastCharge> forecastCharges;

  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: HistoricalChargeScrollView(
        forecastCharges: forecastCharges,
        historicalCharges: historicalCharges,
      ),
    );
  }
}
