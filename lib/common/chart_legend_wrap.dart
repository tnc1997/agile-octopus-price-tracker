import 'package:flutter/material.dart';

import '../forecast/forecast_service.dart';

/// A compact key explaining the two visual encodings used by the price
/// charts: the cheap-to-expensive color gradient, and — where a forecast is
/// plotted alongside confirmed prices — the solid/dashed line distinction.
///
/// The price charts encode two pieces of information visually without
/// labelling either of them on screen: the vertical color gradient painted
/// along the line (derived from [colorStops]) and, on charts that also plot a
/// forecast, the switch from a solid to a dashed line. This widget renders a
/// single, low-profile row that explains both, so a new user is not left to
/// guess at what the colors or the dashing mean.
///
/// The color key is always shown. The line-style key — a "Confirmed" solid
/// line next to a "Forecast" dashed line — is only shown when [forecastCharges]
/// is non-empty, since a chart with no forecast series (for example the
/// history chart, which only ever plots confirmed charges) has nothing dashed
/// to explain.
class ChartLegendWrap extends StatelessWidget {
  const ChartLegendWrap({
    super.key,
    required this.colorStops,
    this.forecastCharges = const [],
  });

  /// The color gradient stops used to color the accompanying chart, ordered
  /// ascending by price. Only the colors are used here; the gradient bar
  /// samples them in order to give a cheap-to-expensive impression without
  /// needing the exact prices they apply at.
  final List<(Color, double)> colorStops;

  /// The forecast charges plotted on the accompanying chart, if any.
  ///
  /// This widget does not read any values off these charges — it only checks
  /// [List.isNotEmpty] to decide whether the accompanying chart has a dashed
  /// forecast series that needs explaining. Passing the same list the chart
  /// itself plots keeps the legend in sync with the chart without either
  /// widget needing a separate "does this chart have a forecast" flag.
  final List<ForecastCharge> forecastCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: [
        Row(
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
                  colors: [
                    for (final colorStop in colorStops) colorStop.$1,
                  ],
                ),
              ),
            ),
            Text(
              'Expensive',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        if (forecastCharges.isNotEmpty) ...[
          const _ChartLegendLineStyleLegendItemRow(
            dashed: false,
            label: 'Confirmed',
          ),
          const _ChartLegendLineStyleLegendItemRow(
            dashed: true,
            label: 'Forecast',
          ),
        ],
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
class _ChartLegendLineStyleLegendItemRow extends StatelessWidget {
  const _ChartLegendLineStyleLegendItemRow({
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
