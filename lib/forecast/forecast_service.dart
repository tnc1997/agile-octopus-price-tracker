import 'package:timezone/timezone.dart' as tz;

import 'neso_api_client.dart';
import 'seasonal_average_lookup_service.dart';

/// A forecast Agile Octopus unit rate for a single half-hour slot.
///
/// This is the forecast counterpart to the `HistoricalCharge` the Octopus Energy
/// API returns for confirmed prices. It deliberately mirrors the three fields the
/// home screen chart reads off a charge — [validFrom], [validTo] and
/// [valueIncVat] — so a forecast slot can be plotted on the same axes as a
/// confirmed one without the chart needing to special-case the two types.
///
/// [valueIncVat] comes from `SeasonalAverageLookupService.predict`, so it carries
/// the same units as a confirmed charge: pence per kWh, inclusive of VAT.
class ForecastCharge {
  /// Creates a forecast charge for a single half-hour slot.
  ///
  /// All three fields are required so that a forecast charge is interchangeable
  /// with a confirmed one everywhere the chart reads [validFrom], [validTo] and
  /// [valueIncVat] off a charge.
  const ForecastCharge({
    required this.validFrom,
    required this.validTo,
    required this.valueIncVat,
  });

  /// The instant the slot begins, in UTC.
  ///
  /// Stamped in UTC to match how the Octopus Energy API stamps a confirmed
  /// charge's `validFrom`, so the two series share an x-axis. The chart converts
  /// it to the device's local zone for display.
  final DateTime validFrom;

  /// The instant the slot ends, in UTC.
  ///
  /// Always exactly 30 minutes after [validFrom], since Agile rates are quoted
  /// per half-hour settlement slot.
  final DateTime validTo;

  /// The forecast unit rate for the slot, in pence per kWh, inclusive of VAT.
  ///
  /// Produced by [SeasonalAverageLookupService.predict] from the slot's
  /// conditions, so it carries the same units as a confirmed charge's
  /// `valueIncVat` and can be plotted on the same y-axis.
  final double valueIncVat;
}

/// Builds a forecast price series for the half-hour slots Octopus has not yet
/// published.
///
/// It bridges the two halves of the forecast: the live NESO generation forecasts
/// (fetched through [NesoApiClient]) say how much wind and solar is expected for
/// each future slot, and [SeasonalAverageLookupService] turns those conditions
/// into a plausible Agile unit rate. The result is a list of [ForecastCharge]s
/// that plot on the same axes as the confirmed prices.
class ForecastService {
  /// Creates a service from the two collaborators it draws on.
  ///
  /// [nesoApiClient] supplies the live wind and solar generation forecasts, and
  /// [seasonalAverageLookupService] turns a slot's conditions into a plausible
  /// price; [getForecastCharges] is where the two are combined. Both are held for
  /// the lifetime of the service, which keeps no other mutable state, so a single
  /// instance can be shared (it is provided app-wide once the lookup table has
  /// loaded).
  ForecastService({
    required NesoApiClient nesoApiClient,
    required SeasonalAverageLookupService seasonalAverageLookupService,
  })  : _nesoApiClient = nesoApiClient,
        _seasonalAverageLookupService = seasonalAverageLookupService;

  final NesoApiClient _nesoApiClient;

  final SeasonalAverageLookupService _seasonalAverageLookupService;

  final tz.Location _location = tz.getLocation('Europe/London');

  /// Forecasts the unit rate for every half-hour slot in `[from, to)`.
  ///
  /// [gsp] is the user's Grid Supply Point group identifier (e.g. `_C`), passed
  /// straight through to [SeasonalAverageLookupService.predict]. [from] is the
  /// instant the forecast should begin — typically the `validTo` of the last
  /// published price, so the series picks up exactly where the confirmed prices
  /// end — and [to] is the (exclusive) end of the window, typically seven days
  /// ahead.
  ///
  /// Both NESO resources are fetched and joined on their shared
  /// (settlement date, settlement period) key. Only slots present in both — so
  /// every generation column is known — and falling inside the window are kept.
  /// The returned list is sorted ascending by [ForecastCharge.validFrom].
  Future<List<ForecastCharge>> getForecastCharges({
    required String gsp,
    required DateTime from,
    required DateTime to,
  }) async {
    // Fetch both forecasts concurrently; neither depends on the other.
    final results = await (
      _nesoApiClient.getEmbeddedSolarAndWindForecast(),
      _nesoApiClient.getFourteenDaysAheadWindForecast(),
    ).wait;

    // Index the wind forecast by settlement slot so each embedded row can find
    // its matching metered-wind figure in constant time.
    final windBySlot = {
      for (final forecast in results.$2)
        (forecast.settlementDate, forecast.settlementPeriod): forecast,
    };

    final charges = <ForecastCharge>[];

    for (final forecast in results.$1) {
      // Skip a slot with no metered-wind reading: without it the renewable total
      // is incomplete and would misclassify the generation level.
      final windForecast = windBySlot[(
        forecast.settlementDate,
        forecast.settlementPeriod,
      )];

      if (windForecast == null) {
        continue;
      }

      // Reconstruct the slot's wall-clock start in Europe/London from its
      // settlement date and period — period 1 begins at local midnight and each
      // step is half an hour — then keep only slots inside the window. Comparing
      // instants, so the UTC/local flag of the bounds does not matter.
      final validFrom = _calculateValidFrom(
        forecast.settlementDate,
        forecast.settlementPeriod,
      );

      if (validFrom.isBefore(from) || !validFrom.isBefore(to)) {
        continue;
      }

      charges.add(
        ForecastCharge(
          validFrom: validFrom.toUtc(),
          validTo: validFrom.add(const Duration(minutes: 30)).toUtc(),
          valueIncVat: _seasonalAverageLookupService.predict(
            gsp: gsp,
            dateTime: validFrom,
            embeddedWindMw: forecast.embeddedWindForecastMw,
            embeddedSolarMw: forecast.embeddedSolarForecastMw,
            windMw: windForecast.windForecastMw,
          ),
        ),
      );
    }

    // The embedded resource is broadly ordered, but sort defensively so the
    // step-line series is drawn left to right regardless of the feed's order.
    charges.sort((a, b) => a.validFrom.compareTo(b.validFrom));

    return charges;
  }

  /// The Europe/London instant a settlement slot begins.
  ///
  /// Period 1 starts at local midnight on [settlementDate] and each successive
  /// period is 30 minutes later, mirroring how the build script maps a timestamp
  /// back to a period. Returned as a [tz.TZDateTime] so it carries the correct
  /// UTC instant across British Summer Time.
  tz.TZDateTime _calculateValidFrom(
    String settlementDate,
    int settlementPeriod,
  ) {
    final parts = settlementDate.split('-');

    return tz.TZDateTime(
      _location,
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    ).add(Duration(minutes: (settlementPeriod - 1) * 30));
  }
}
