import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';

import 'historical_charge_summary_statistic_card.dart';

class HistoricalChargeSummary extends StatelessWidget {
  const HistoricalChargeSummary({
    super.key,
    required this.historicalCharges,
  });

  /// The charges the average, lowest and highest prices are computed over.
  ///
  /// Must not be empty; the history screen shows an empty state instead when
  /// there are no charges for the selected range.
  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    var sum = 0.0;
    var min = double.infinity;
    var max = double.negativeInfinity;
    var length = 0;

    for (final historicalCharge in historicalCharges) {
      sum += historicalCharge.valueIncVat;

      if (historicalCharge.valueIncVat < min) {
        min = historicalCharge.valueIncVat;
      }

      if (historicalCharge.valueIncVat > max) {
        max = historicalCharge.valueIncVat;
      }

      length++;
    }

    return Row(
      spacing: 16.0,
      children: [
        Expanded(
          child: HistoricalChargeSummaryStatisticCard(
            label: 'Average',
            value: sum / length,
          ),
        ),
        Expanded(
          child: HistoricalChargeSummaryStatisticCard(
            label: 'Lowest',
            value: min,
          ),
        ),
        Expanded(
          child: HistoricalChargeSummaryStatisticCard(
            label: 'Highest',
            value: max,
          ),
        ),
      ],
    );
  }
}
