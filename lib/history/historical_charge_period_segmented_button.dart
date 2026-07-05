import 'package:flutter/material.dart';

import 'historical_charge_period.dart';

class HistoricalChargePeriodSegmentedButton extends StatelessWidget {
  const HistoricalChargePeriodSegmentedButton({
    super.key,
    required this.selected,
    required this.onSelectionChanged,
  });

  /// The period whose segment is currently highlighted, or null when a custom
  /// date range is in effect and no segment should appear selected.
  ///
  /// Rendered as the button's selection set — an empty set when null — which is
  /// why [SegmentedButton.emptySelectionAllowed] must be enabled below.
  final HistoricalChargePeriod? selected;

  /// Called when the user chooses a period, with the segment they tapped.
  ///
  /// Only ever invoked with a period. Because the button allows an empty
  /// selection, tapping the already-selected segment deselects it and reports
  /// an empty set; that case is swallowed rather than surfaced, so the caller
  /// never has to handle a "no period" callback.
  final void Function(HistoricalChargePeriod) onSelectionChanged;

  @override
  Widget build(
    BuildContext context,
  ) {
    return SegmentedButton<HistoricalChargePeriod>(
      segments: [
        for (final period in HistoricalChargePeriod.values)
          ButtonSegment(
            value: period,
            label: Text(
              switch (period) {
                HistoricalChargePeriod.sevenDays => '7 days',
                HistoricalChargePeriod.thirtyDays => '30 days',
                HistoricalChargePeriod.threeMonths => '3 months',
                HistoricalChargePeriod.twelveMonths => '12 months',
              },
            ),
          ),
      ],
      selected: {
        if (selected case final selected?) selected,
      },
      onSelectionChanged: (periods) {
        // Tapping the selected segment deselects it (emptySelectionAllowed),
        // so ignore the resulting empty set rather than reading `.single`.
        if (periods.isNotEmpty) {
          onSelectionChanged(periods.first);
        }
      },
      // A custom date range clears the selection, so no chip is highlighted;
      // without this the empty selection would trip SegmentedButton's assert.
      emptySelectionAllowed: true,
      // By default the selected icon is shown which reduces the width that
      // is available for the label text in the button segment.
      showSelectedIcon: false,
    );
  }
}
