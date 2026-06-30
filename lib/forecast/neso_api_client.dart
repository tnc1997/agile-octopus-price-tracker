import 'dart:convert';

import 'package:http/http.dart' as http;

/// One row of the NESO Embedded Solar and Wind Forecast.
///
/// NESO estimates the output of "embedded" wind and solar farms — the smaller
/// generators wired into the local distribution network rather than the national
/// transmission grid — because their output is not metered directly. Both figures
/// feed the renewable total the seasonal average lookup classifies on.
///
/// [settlementDate] and [settlementPeriod] identify the half-hour slot in UK
/// local (clock) time, the convention NESO publishes in and the one the lookup
/// table was built against, so they line up with the wind forecast and with the
/// price history without any timezone conversion.
class EmbeddedSolarAndWindForecast {
  /// Creates a forecast row for a single half-hour settlement slot.
  ///
  /// Every value is required: a row is only meaningful once its slot is pinned
  /// down by [settlementDate] and [settlementPeriod] and both generation figures
  /// are known, because the embedded wind and solar forecasts are summed
  /// (together with the metered wind forecast) into the single renewable total
  /// that drives the price lookup.
  const EmbeddedSolarAndWindForecast({
    required this.settlementDate,
    required this.settlementPeriod,
    required this.embeddedWindForecastMw,
    required this.embeddedSolarForecastMw,
  });

  /// The calendar date of the slot, in UK local (clock) time, as `YYYY-MM-DD`.
  ///
  /// Read from the resource's `SETTLEMENT_DATE` column with any time component
  /// trimmed off. Together with [settlementPeriod] it forms the key the embedded
  /// and wind forecasts are joined on, and the same key the offline build script
  /// bucketed the historical prices under — so the three line up without any
  /// timezone conversion.
  final String settlementDate;

  /// The half-hour slot's index within its [settlementDate], in UK local time.
  ///
  /// Period 1 covers 00:00-00:30 and period 48 covers 23:30-24:00; on the two
  /// clock-change days a local day has 46 or 50 periods rather than 48. Paired
  /// with [settlementDate] it uniquely identifies the slot.
  final int settlementPeriod;

  /// The estimated embedded wind generation for the slot, in megawatts.
  ///
  /// "Embedded" wind is wired into the local distribution network rather than the
  /// metered transmission grid, so NESO estimates its output rather than
  /// measuring it. Read from the `EMBEDDED_WIND_FORECAST` column.
  final double embeddedWindForecastMw;

  /// The estimated embedded solar generation for the slot, in megawatts.
  ///
  /// Read from the `EMBEDDED_SOLAR_FORECAST` column; like [embeddedWindForecastMw]
  /// it is an estimate of distribution-connected output rather than a metered
  /// figure.
  final double embeddedSolarForecastMw;
}

/// One row of the NESO 14 Days Ahead Wind Forecast.
///
/// This is the day-ahead-style forecast of national, transmission-connected
/// (metered) wind generation — the large wind farms NESO meters directly — for
/// each half-hour slot up to 14 days out. It is the third column summed into the
/// renewable total alongside the embedded wind and solar figures.
///
/// [settlementDate] and [settlementPeriod] identify the half-hour slot in UK
/// local (clock) time, matching [EmbeddedSolarAndWindForecast] so the two can be
/// joined on this key.
class FourteenDaysAheadWindForecast {
  /// Creates a forecast row for a single half-hour settlement slot.
  ///
  /// Every value is required: the slot must be identified by [settlementDate]
  /// and [settlementPeriod] so it can be joined to the matching embedded
  /// forecast, and [windForecastMw] is the figure that join exists to retrieve.
  const FourteenDaysAheadWindForecast({
    required this.settlementDate,
    required this.settlementPeriod,
    required this.windForecastMw,
  });

  /// The calendar date of the slot, in UK local (clock) time, as `YYYY-MM-DD`.
  ///
  /// Read from the resource's `Date` column. With [settlementPeriod] it forms
  /// the key this forecast is joined to [EmbeddedSolarAndWindForecast] on.
  final String settlementDate;

  /// The half-hour slot's index within its [settlementDate], in UK local time.
  ///
  /// Period 1 covers 00:00-00:30 and period 48 covers 23:30-24:00, matching the
  /// convention [EmbeddedSolarAndWindForecast.settlementPeriod] uses so the two
  /// resources align on the same slots.
  final int settlementPeriod;

  /// The forecast national metered wind generation for the slot, in megawatts.
  ///
  /// Read from the `Wind_Forecast` column. Unlike the embedded figures this is
  /// transmission-connected wind that NESO meters directly; it is the third term
  /// summed into the renewable total the price lookup classifies on.
  final double windForecastMw;
}

/// A thin client over the NESO (National Energy System Operator) data portal.
///
/// The portal is a CKAN open-data instance: each dataset table ("resource") is
/// queryable through the `datastore_search` action, which returns JSON. This
/// client fetches the two live, forward-looking forecast resources the price
/// forecast needs — the Embedded Solar and Wind Forecast and the 14 Days Ahead
/// Wind Forecast — and parses each into typed rows.
///
/// Both resources are small (a few hundred rows covering roughly two weeks
/// ahead) and hold a single revision per slot, so each is fetched in one request
/// with a generous row limit rather than paged. The historical archives the
/// `script/` collectors download are deliberately not touched here: at runtime we
/// only want the future slots the bundled lookup table cannot already price.
class NesoApiClient {
  /// Creates a client for the NESO data portal.
  ///
  /// Pass [client] to supply a custom [http.Client] — a mock in tests, or a
  /// client preconfigured with a proxy or shared connection pool. When omitted, a
  /// default [http.Client] is created and used for every request the client
  /// makes.
  NesoApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// The CKAN `datastore_search` action endpoint every query is built on.
  static final _datastoreSearchUri = Uri.parse(
    'https://api.neso.energy/api/3/action/datastore_search',
  );

  /// The resource id of the live Embedded Solar and Wind Forecast table.
  static const _embeddedSolarAndWindForecastResourceId =
      'db6c038f-98af-4570-ab60-24d71ebd0ae5';

  /// The resource id of the live 14 Days Ahead Wind Forecast table.
  static const _fourteenDaysAheadWindForecastResourceId =
      '93c3048e-1dab-4057-a2a9-417540583929';

  /// The per-request row cap. Comfortably above the ~700 rows either resource
  /// holds (roughly 14 days x 48 half-hour slots), so a single request returns
  /// the whole forward window without paging.
  static const _limit = 1000;

  final http.Client _client;

  /// Fetches the live Embedded Solar and Wind Forecast.
  ///
  /// Returns one [EmbeddedSolarAndWindForecast] per future half-hour slot the
  /// resource publishes. Throws if the request fails or the response is not the
  /// expected CKAN document.
  Future<List<EmbeddedSolarAndWindForecast>>
      getEmbeddedSolarAndWindForecast() async {
    final records = await _getRecords(_embeddedSolarAndWindForecastResourceId);

    return records.map((record) {
      return EmbeddedSolarAndWindForecast(
        settlementDate: _normalizeDate(record['SETTLEMENT_DATE']),
        settlementPeriod: (record['SETTLEMENT_PERIOD'] as num).toInt(),
        embeddedWindForecastMw: _parseMw(record['EMBEDDED_WIND_FORECAST']),
        embeddedSolarForecastMw: _parseMw(record['EMBEDDED_SOLAR_FORECAST']),
      );
    }).toList();
  }

  /// Fetches the live 14 Days Ahead Wind Forecast.
  ///
  /// Returns one [FourteenDaysAheadWindForecast] per future half-hour slot the resource publishes.
  /// Throws if the request fails or the response is not the expected CKAN
  /// document.
  Future<List<FourteenDaysAheadWindForecast>>
      getFourteenDaysAheadWindForecast() async {
    final records = await _getRecords(_fourteenDaysAheadWindForecastResourceId);

    return records.map((record) {
      return FourteenDaysAheadWindForecast(
        settlementDate: _normalizeDate(record['Date']),
        settlementPeriod: (record['Settlement_Period'] as num).toInt(),
        windForecastMw: _parseMw(record['Wind_Forecast']),
      );
    }).toList();
  }

  /// Runs a `datastore_search` for [resourceId] and returns its `records`.
  ///
  /// Every CKAN response wraps its payload in a `success` flag and a `result`
  /// object; this checks the flag, surfaces a clear error otherwise, and hands
  /// back the raw record maps for the caller to map into typed rows.
  Future<List<Map<String, dynamic>>> _getRecords(
    String resourceId,
  ) async {
    final response = await _client.get(
      _datastoreSearchUri.replace(
        queryParameters: {
          'resource_id': resourceId,
          'limit': '$_limit',
        },
      ),
    );

    if (response.statusCode != 200) {
      throw http.ClientException(
        'NESO datastore_search returned ${response.statusCode}',
        _datastoreSearchUri,
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw http.ClientException(
        'NESO datastore_search reported failure for $resourceId',
        _datastoreSearchUri,
      );
    }

    return body['result']['records'].cast<Map<String, dynamic>>();
  }

  /// Normalizes a NESO date field to `YYYY-MM-DD`.
  ///
  /// The two resources spell the same date differently — the wind table as a
  /// bare `2026-06-29`, the embedded table as a timestamp `2026-06-29T00:00:00` —
  /// so the leading ten characters are kept to give both a single join key.
  static String _normalizeDate(
    dynamic value,
  ) {
    return (value as String).substring(0, 10);
  }

  /// Parses a megawatt field, which CKAN may type as a number or a string.
  static double _parseMw(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.parse(value as String);
  }
}
