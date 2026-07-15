import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';

import '../forecast/forecast_service.dart';
import 'functions.dart';

/// A compact key explaining the visual encodings used by the price charts:
/// the cheap-to-expensive color gradient, the distinct color used for
/// negative-price periods, and — where a forecast is plotted alongside
/// confirmed prices — the solid/dashed line distinction.
///
/// The price charts encode these pieces of information visually without
/// labelling them on screen: the vertical color gradient painted along the
/// line (derived from [colorStops]), the distinct color a negative price is
/// drawn in (see [calculatePriceColor]) and, on charts that also plot a
/// forecast, the switch from a solid to a dashed line. This widget renders a
/// single, low-profile key that explains all of them, so a new user is not
/// left to guess at what the colors or the dashing mean.
///
/// The color-based entries — "Negative" (when [hasNegativePrice] is true) and
/// the Cheap/Expensive gradient — are grouped on one row, and the line-style
/// entries — "Confirmed" and "Forecast" — on another, so that each group
/// wraps as a whole rather than splitting mid-group: on desktop widths both
/// rows fit on a single line, while on mobile widths they fall onto two
/// consistent rows regardless of whether the "Negative" entry is present.
///
/// The line-style key is only shown when [forecastCharges] is non-empty,
/// since a chart with no forecast series (for example the history chart,
/// which only ever plots confirmed charges) has nothing dashed to explain.
class ChartLegendWrap extends StatelessWidget {
  const ChartLegendWrap({
    super.key,
    required this.colorStops,
    this.forecastCharges = const [],
    required this.historicalCharges,
  });

  /// The color gradient stops used to color the accompanying chart, ordered
  /// ascending by price. Only the colors are used here; the gradient bar
  /// samples them in order to give a cheap-to-expensive impression without
  /// needing the exact prices they apply at.
  final List<(Color, double)> colorStops;

  /// The forecast charges plotted on the accompanying chart, if any.
  ///
  /// Checked for [List.isNotEmpty] to decide whether the accompanying chart
  /// has a dashed forecast series that needs explaining, and scanned
  /// alongside [historicalCharges] for a negative `valueIncVat` to decide
  /// whether the "Negative" legend entry is needed. Passing the same list the
  /// chart itself plots keeps the legend in sync with the chart without
  /// either widget needing separate flags.
  final List<ForecastCharge> forecastCharges;

  /// The confirmed charges plotted on the accompanying chart.
  ///
  /// This widget does not otherwise use these values — it only scans them for
  /// a negative `valueIncVat` to decide whether the "Negative" legend entry
  /// is needed. Passing the same list the chart itself plots keeps the
  /// legend in sync with the chart without a separate "does this chart have
  /// a negative price" flag.
  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    // Negative pricing is an unusual, occasional event rather than a
    // permanent feature of every day's data, so the "Negative" legend entry
    // is only rendered when the data actually plotted on the accompanying
    // chart contains one.
    var hasNegativePrice = false;

    if (hasNegativePrice != true) {
      for (final forecastCharge in forecastCharges) {
        if (forecastCharge.valueIncVat < 0) {
          hasNegativePrice = true;
        }
      }
    }

    if (hasNegativePrice != true) {
      for (final historicalCharge in historicalCharges) {
        if (historicalCharge.valueIncVat < 0) {
          hasNegativePrice = true;
        }
      }
    }

    return Wrap(
      spacing: 12.0,
      runSpacing: 4.0,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8.0,
          children: [
            if (true)
              _ChartLegendColorSwatchRow(
                // Any negative value resolves to the same color
                // `calculatePriceColor` draws every negative price in on the
                // chart, so this stays in sync with the chart without
                // duplicating its negative-price color logic.
                color: calculatePriceColor(colorStops, -1) ??
                    const Color(0xff00ffff),
                label: 'Negative',
              ),
            _ChartLegendColorGradientRow(
              colorStops: colorStops,
            ),
          ],
        ),
        if (forecastCharges.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8.0,
            children: const [
              _ChartLegendLineStyleRow(
                dashed: false,
                label: 'Confirmed',
              ),
              _ChartLegendLineStyleRow(
                dashed: true,
                label: 'Forecast',
              ),
            ],
          ),
      ],
    );
  }
}

/// The Cheap/Expensive entry in the color key: a horizontal gradient bar
/// sampling [colorStops] in order, with "Cheap" and "Expensive" labels either
/// side.
///
/// Kept as its own widget, rather than inlined in [ChartLegendWrap], so it
/// reads as its own self-contained legend entry alongside the "Negative"
/// swatch it sits next to.
class _ChartLegendColorGradientRow extends StatelessWidget {
  const _ChartLegendColorGradientRow({
    required this.colorStops,
  });

  /// The color gradient stops used to color the accompanying chart, ordered
  /// ascending by price. The gradient bar samples colors for positive values
  /// in order to give a cheap-to-expensive impression.
  final List<(Color, double)> colorStops;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors = <Color>[];

    for (final colorStop in colorStops) {
      if (colorStop.$2 >= 0) {
        colors.add(colorStop.$1);
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4.0,
      children: [
        Text(
          'Cheap',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        Container(
          width: 32.0,
          height: 8.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.0),
            gradient: LinearGradient(
              colors: colors,
            ),
          ),
        ),
        Text(
          'Expensive',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

/// A single entry in the color key: a small solid swatch next to a label
/// explaining what it represents.
///
/// Used for the "Negative" entry, matching the swatch-plus-label shape of
/// the Cheap/Expensive gradient entry it sits alongside so the two read as
/// part of the same color key.
class _ChartLegendColorSwatchRow extends StatelessWidget {
  const _ChartLegendColorSwatchRow({
    required this.color,
    required this.label,
  });

  /// The swatch color, matching the color the accompanying chart draws
  /// negative prices in.
  final Color color;

  /// The text shown next to the swatch, e.g. `'Negative'`.
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4.0,
      children: [
        Container(
          width: 16.0,
          height: 8.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.0),
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

/// A single entry in the line-style key: a short line — solid or dashed —
/// next to a label explaining what it represents.
///
/// [ChartLegendWrap] renders two of these side by side, one for "Confirmed"
/// ([dashed] false) and one for "Forecast" ([dashed] true), matching the
/// solid/dashed styling the accompanying chart itself applies to its two
/// series. Keeping the legend item as its own widget, rather than inlining
/// it twice in [ChartLegendWrap], keeps the two entries visually identical by
/// construction.
class _ChartLegendLineStyleRow extends StatelessWidget {
  const _ChartLegendLineStyleRow({
    required this.dashed,
    required this.label,
  });

  /// Whether the line is drawn dashed (true) or solid (false).
  ///
  /// A dashed line is built from a short row of small, evenly-spaced
  /// [Container]s rather than an actual dashed [BorderSide] or similar,
  /// since Flutter has no built-in dashed line primitive; a solid line is
  /// just a single wide [Container].
  final bool dashed;

  /// The text shown next to the line, e.g. `'Confirmed'` or `'Forecast'`.
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4.0,
      children: [
        if (dashed)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2.0,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 4.0,
                  height: 2.0,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            ],
          )
        else
          Container(
            width: 24.0,
            height: 2.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}
