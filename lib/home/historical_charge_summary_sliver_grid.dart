import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';

import 'historical_charge_summary_card.dart';

class HistoricalChargeSummarySliverGrid extends StatelessWidget {
  const HistoricalChargeSummarySliverGrid({
    super.key,
    required this.colorStops,
    required this.historicalCharges,
  });

  final List<(Color, double)> colorStops;

  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    HistoricalCharge? min;
    HistoricalCharge? max;

    for (final historicalCharge in historicalCharges) {
      if (min == null || historicalCharge.valueIncVat < min.valueIncVat) {
        min = historicalCharge;
      }

      if (max == null || historicalCharge.valueIncVat > max.valueIncVat) {
        max = historicalCharge;
      }
    }

    return SliverGrid(
      delegate: SliverChildListDelegate.fixed(
        [
          HistoricalChargeSummaryCard(
            colorStops: colorStops,
            label: 'Current',
            sublabel: '${DateFormat.Hm().format(
              historicalCharges[0].validFrom!.toLocal(),
            )} - ${DateFormat.Hm().format(
              historicalCharges[0].validTo!.toLocal(),
            )}',
            value: historicalCharges[0].valueIncVat,
          ),
          HistoricalChargeSummaryCard(
            colorStops: colorStops,
            label: 'Next',
            sublabel: '${DateFormat.Hm().format(
              historicalCharges[1].validFrom!.toLocal(),
            )} - ${DateFormat.Hm().format(
              historicalCharges[1].validTo!.toLocal(),
            )}',
            value: historicalCharges[1].valueIncVat,
          ),
          if (min != null)
            HistoricalChargeSummaryCard(
              colorStops: colorStops,
              label: 'Best',
              sublabel: '${DateFormat.Hm().format(
                min.validFrom!.toLocal(),
              )} - ${DateFormat.Hm().format(
                min.validTo!.toLocal(),
              )}',
              value: min.valueIncVat,
            ),
          if (max != null)
            HistoricalChargeSummaryCard(
              colorStops: colorStops,
              label: 'Avoid',
              sublabel: '${DateFormat.Hm().format(
                max.validFrom!.toLocal(),
              )} - ${DateFormat.Hm().format(
                max.validTo!.toLocal(),
              )}',
              value: max.valueIncVat,
            )
        ],
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 768 ? 4 : 2,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        childAspectRatio: 2.0,
      ),
    );
  }
}
