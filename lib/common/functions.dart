import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'extensions.dart';

/// Builds the vertical gradient used to color a price series by value.
///
/// A series' `onCreateShader` paints every segment — including the vertical
/// riser between two slots — with this shader stretched across the whole plot
/// area, so each pixel is colored by its position rather than by the color of
/// the point that owns the segment (which left risers overflowing their band;
/// see issue #32). Because the price axis is pinned to [minimum]..[maximum]
/// with no range padding, a pixel's vertical position is its price: the bottom
/// edge is [minimum] and the top edge is [maximum].
///
/// The colors are sampled from [calculatePriceColor] evenly across that range
/// so the gradient tracks the configured color stops.
LinearGradient buildPriceGradient(
  List<(Color, double)> colorStops,
  double minimum,
  double maximum,
) {
  // The gradient is defined by sampling [calculatePriceColor] at a fixed number
  // of prices and letting Flutter interpolate between the samples. The math
  // that lines each sample up with the price it represents:
  //
  // Flutter spaces a gradient's colors evenly when no explicit `stops` are
  // given — with N colors, color i sits at fraction i / (N - 1) along the
  // gradient, so color 0 is at fraction 0.0 and color N - 1 is at 1.0. With
  // `begin: bottomCenter` and `end: topCenter` the gradient runs bottom to
  // top, so fraction 0.0 is the plot area's bottom edge and 1.0 its top edge.
  // Because the price axis is pinned to [minimum]..[maximum] (see the doc
  // comment), those edges are the prices [minimum] and [maximum].
  //
  // A point at fraction t up the plot area therefore represents the price
  //
  //     price(t) = minimum + t * (maximum - minimum),
  //
  // a linear map from the unit interval [0, 1] onto [minimum, maximum]. To
  // give sample i the right color we evaluate that map at the sample's own
  // fraction, t = i / (N - 1):
  //
  //     price_i = minimum + (maximum - minimum) * i / (N - 1),
  //
  // which is the value handed to [calculatePriceColor] below. The endpoints
  // fall exactly on the range: i = 0 yields [minimum] and i = N - 1 yields
  // [maximum]. Dividing by N - 1 rather than N is what places the last sample
  // on the top edge instead of one step short of it — there are N samples but
  // only N - 1 gaps between them.
  //
  // Flutter interpolates linearly between adjacent samples. [calculatePriceColor]
  // is itself piecewise-linear in price, so the only deviation is the tiny
  // chord-versus-line gap where a color stop falls between two samples; at
  // N = 64 across a realistic price range each gap spans well under a pixel,
  // so it is not visible.
  const samples = 64;

  final colors = <Color>[];

  for (var i = 0; i < samples; i++) {
    final value = minimum + (maximum - minimum) * i / (samples - 1);

    if (calculatePriceColor(colorStops, value) case final color?) {
      colors.add(color);
    } else {
      colors.add(Colors.transparent);
    }
  }

  return LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: colors,
  );
}

/// Maps a unit rate to its color by interpolating between the configured
/// [colorStops], so a confirmed charge and a forecast charge of the same price
/// are shown in the same color.
Color? calculatePriceColor(
  List<(Color, double)> colorStops,
  double value,
) {
  if (value < 0) {
    for (final colorStop in colorStops) {
      if (colorStop.$2 < 0) {
        return colorStop.$1;
      }
    }

    return Color(0xff00ffff);
  }

  for (var i = 0; i < colorStops.length - 1; i++) {
    if (value < colorStops[i].$2) {
      return colorStops[i].$1;
    }

    if (value < colorStops[i + 1].$2) {
      return Color.lerp(
        colorStops[i].$1,
        colorStops[i + 1].$1,
        value.remap(
          colorStops[i].$2,
          colorStops[i + 1].$2,
          0,
          1,
        ),
      );
    }
  }

  return colorStops.last.$1;
}

/// Finds the cheapest contiguous window of [duration] within [historicalCharges].
///
/// Running an appliance needs a sustained low price, not just one favourable
/// slot, so this looks for a run of consecutive charges — each one's
/// `validFrom` matching the previous one's `validTo`, with no gaps — spanning
/// exactly [duration], and returns whichever such window has the lowest
/// average `valueIncVat`, alongside that average. Returns `null` if
/// [historicalCharges] contains no window of that exact length.
(List<HistoricalCharge>, double)? findCheapestWindow(
  List<HistoricalCharge> historicalCharges,
  Duration duration,
) {
  // Tracks the cheapest window found so far, across every starting position.
  List<HistoricalCharge>? cheapestWindow;
  // Its average `valueIncVat`, kept alongside so it isn't recomputed later.
  double? cheapestAverage;

  // Try every possible starting slot as the beginning of a candidate window.
  for (var i = 0; i < historicalCharges.length; i++) {
    // The window always starts with the slot at `i` itself.
    final window = [historicalCharges[i]];
    // Running total of `valueIncVat` for the slots in `window`, seeded with
    // the starting slot since the loop below only adds to it from `i + 1`.
    var sum = historicalCharges[i].valueIncVat;
    // Count of slots in `window`, seeded to match `sum` above.
    var length = 1;

    // Extend the window forwards, one slot at a time, from `i`.
    for (var j = i + 1; j < historicalCharges.length; j++) {
      final previous = historicalCharges[j - 1];
      final current = historicalCharges[j];

      // A gap between slots breaks contiguity, so this window can't be
      // extended any further.
      if (current.validFrom != previous.validTo) {
        break;
      }

      // Adding this slot would overshoot the requested duration, so stop
      // before it's included.
      if (current.validTo!.difference(historicalCharges[i].validFrom!) >
          duration) {
        break;
      }

      // The slot fits within the window, so include it.
      window.add(current);
      sum += current.valueIncVat;
      length++;
    }

    // The window built above didn't reach exactly `duration` (either the
    // charges ran out or a gap stopped it short), so it's not a valid
    // candidate.
    if (window.last.validTo!.difference(historicalCharges[i].validFrom!) !=
        duration) {
      continue;
    }

    // Keep this window if it's the first valid one found, or cheaper than
    // the best one seen so far.
    if (cheapestAverage == null || sum / length < cheapestAverage) {
      cheapestWindow = window;
      cheapestAverage = sum / length;
    }
  }

  // No starting position produced a window of exactly `duration`.
  if (cheapestWindow == null || cheapestAverage == null) {
    return null;
  }

  return (cheapestWindow, cheapestAverage);
}

/// Gets the color gradient stops used to color a price by its unit rate.
///
/// Reads the persisted `color_stops` preference, falling back to a built-in
/// default when the user has not configured any. Each entry pairs a color with
/// the price (in pence per kWh) it applies at, ordered ascending by price;
/// [calculatePriceColor] interpolates between adjacent stops.
Future<List<(Color, double)>> getColorStops(
  SharedPreferencesAsync preferences,
) async {
  if (await preferences.getString('color_stops') case final source?) {
    final colorStops = <(Color, double)>[];

    for (final value in json.decode(source) as List<dynamic>) {
      colorStops.add((
        Color(value['color'] as int),
        value['price'] as double,
      ));
    }

    return colorStops;
  }

  return const [
    (defaultNegativeColor, -1.00),
    (defaultLowColor, defaultLowPrice),
    (defaultMediumColor, defaultMediumPrice),
    (defaultHighColor, defaultHighPrice),
  ];
}

/// Gets the threshold, in pence per kilowatt hour, that the today's summary
/// card's 'hours below' row counts against.
///
/// Reads the persisted `hours_below_threshold` preference, falling back to
/// 15.00 — the value this row was hard-coded to before it became
/// user-configurable — so behaviour is unchanged until a user actively
/// changes it. This is a distinct preference from `color_stops`: the two
/// happen to default to a similar price, but serve different purposes (colour
/// banding across four tiers, versus a single pass/fail cutoff for one stat)
/// and are not unified.
Future<double> getHoursBelowThreshold(
  SharedPreferencesAsync preferences,
) async {
  return await preferences.getDouble('hours_below_threshold') ??
      defaultHoursBelowThreshold;
}

/// Gets the tariff comparison rate, in pence per kWh, that the today's
/// summary card's tariff comparison sentence compares today's average
/// against.
///
/// Reads the persisted `tariff_comparison_rate` preference, which is always
/// set by the time this is called — the welcome screen requires it, the same
/// as `grid_supply_point_group_id` and `import_product_code` (see the
/// redirect in `lib/main.dart`).
Future<double> getTariffComparisonRate(
  SharedPreferencesAsync preferences,
) async {
  return await preferences.getDouble('tariff_comparison_rate') ??
      defaultTariffComparisonRate;
}
