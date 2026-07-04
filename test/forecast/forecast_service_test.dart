import 'dart:convert';

import 'package:agile_octopus_price_tracker/forecast/forecast_service.dart';
import 'package:agile_octopus_price_tracker/forecast/neso_api_client.dart';
import 'package:agile_octopus_price_tracker/forecast/price_forecast_model_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart' as tz;

/// A [PriceForecastModelService] test double whose [predict] returns a constant
/// 7.0 for every slot.
///
/// That keeps these tests about the service's own job — fetching, joining,
/// windowing, instant math and ordering — rather than model inference. It is a
/// fake rather than a real model because the ONNX Runtime native library the
/// real service loads is unavailable under `flutter test`, and inference parity
/// is verified by `script/export_price_forecast_model.py` in any case.
/// Implemented via `implements` so no session is constructed; only [predict] is
/// exercised, and the unused members fall through to [noSuchMethod].
class _FakePriceForecastModelService extends Fake
    implements PriceForecastModelService {
  @override
  Future<double> predict({
    required String gsp,
    required DateTime dateTime,
    required double embeddedWindMw,
    required double embeddedSolarMw,
    required double windMw,
  }) async {
    return 7.0;
  }
}

/// A [NesoApiClient] backed by a [MockClient] that returns [embedded] for the
/// embedded resource and [wind] for the wind resource, branching on the
/// `resource_id` query parameter.
NesoApiClient _client({
  required List<Map<String, dynamic>> embedded,
  required List<Map<String, dynamic>> wind,
}) {
  return NesoApiClient(
    client: MockClient((request) async {
      return http.Response(
        json.encode({
          'success': true,
          'result': {
            'records': switch (request.url.queryParameters['resource_id']) {
              'db6c038f-98af-4570-ab60-24d71ebd0ae5' => embedded,
              '93c3048e-1dab-4057-a2a9-417540583929' => wind,
              _ => [],
            },
          },
        }),
        200,
      );
    }),
  );
}

/// A CKAN record for the embedded forecast.
Map<String, dynamic> _embedded(
  String date,
  int period,
) {
  return {
    'SETTLEMENT_DATE': '${date}T00:00:00',
    'SETTLEMENT_PERIOD': period,
    'EMBEDDED_WIND_FORECAST': 100,
    'EMBEDDED_SOLAR_FORECAST': 200,
  };
}

/// A CKAN record for the wind forecast.
Map<String, dynamic> _wind(
  String date,
  int period,
) {
  return {
    'Date': date,
    'Settlement_Period': period,
    'Wind_Forecast': 300,
  };
}

void main() {
  group(
    'ForecastService',
    () {
      late final PriceForecastModelService priceForecastModelService;

      setUpAll(
        () {
          initializeTimeZones();

          priceForecastModelService = _FakePriceForecastModelService();
        },
      );

      test(
        'forecasts each slot present in both feeds and inside the window during British Summer Time',
        () async {
          // British Summer Time, so 2026-07-01 period 1 (00:00 local) is
          // 2026-06-30T23:00:00Z and each later period is 30 minutes on.
          final forecastService = ForecastService(
            nesoApiClient: _client(
              embedded: [
                _embedded('2026-06-30', 48), // before the window
                _embedded('2026-07-01', 1),
                _embedded('2026-07-01', 2),
                _embedded('2026-07-01', 3),
                _embedded('2026-07-01', 4), // no matching wind
                _embedded('2026-07-01', 5), // at the window end (exclusive)
              ],
              wind: [
                _wind('2026-06-30', 48),
                _wind('2026-07-01', 1),
                _wind('2026-07-01', 2),
                _wind('2026-07-01', 3),
                _wind('2026-07-01', 5),
              ],
            ),
            priceForecastModelService: priceForecastModelService,
          );

          final charges = await forecastService.getForecastCharges(
            gsp: '_C',
            from: DateTime.utc(2026, 6, 30, 23, 0),
            to: DateTime.utc(2026, 7, 1, 1, 0),
          );

          // Periods 1-3 only: period 4 lacks a wind reading and period 5 starts
          // at the exclusive end of the window.
          expect(
            charges,
            hasLength(3),
          );

          expect(
            charges[0].validFrom,
            DateTime.utc(2026, 6, 30, 23, 0),
          );

          expect(
            charges[0].validTo,
            DateTime.utc(2026, 6, 30, 23, 30),
          );

          expect(
            charges[1].validFrom,
            DateTime.utc(2026, 6, 30, 23, 30),
          );

          expect(
            charges[2].validFrom,
            DateTime.utc(2026, 7, 1, 0, 0),
          );

          // The fake forecaster resolves every slot to a constant.
          expect(
            charges.map((charge) => charge.valueIncVat),
            everyElement(7.0),
          );
        },
      );

      test(
        'forecasts each slot present in both feeds and inside the window during Greenwich Mean Time',
        () async {
          // Greenwich Mean Time, so 2026-01-01 period 1 (00:00 local) is
          // 2026-01-01T00:00:00Z and each later period is 30 minutes on. This is
          // the winter counterpart to the British Summer Time case above, where
          // the same period maps an hour earlier in UTC — the London offset the
          // service must apply differs by season.
          final forecastService = ForecastService(
            nesoApiClient: _client(
              embedded: [
                _embedded('2025-12-31', 48), // before the window
                _embedded('2026-01-01', 1),
                _embedded('2026-01-01', 2),
                _embedded('2026-01-01', 3),
                _embedded('2026-01-01', 4), // no matching wind
                _embedded('2026-01-01', 5), // at the window end (exclusive)
              ],
              wind: [
                _wind('2025-12-31', 48),
                _wind('2026-01-01', 1),
                _wind('2026-01-01', 2),
                _wind('2026-01-01', 3),
                _wind('2026-01-01', 5),
              ],
            ),
            priceForecastModelService: priceForecastModelService,
          );

          final charges = await forecastService.getForecastCharges(
            gsp: '_C',
            from: DateTime.utc(2026, 1, 1, 0, 0),
            to: DateTime.utc(2026, 1, 1, 2, 0),
          );

          // Periods 1-3 only: period 4 lacks a wind reading and period 5 starts
          // at the exclusive end of the window.
          expect(
            charges,
            hasLength(3),
          );

          expect(
            charges[0].validFrom,
            DateTime.utc(2026, 1, 1, 0, 0),
          );

          expect(
            charges[0].validTo,
            DateTime.utc(2026, 1, 1, 0, 30),
          );

          expect(
            charges[1].validFrom,
            DateTime.utc(2026, 1, 1, 0, 30),
          );

          expect(
            charges[2].validFrom,
            DateTime.utc(2026, 1, 1, 1, 0),
          );

          // The fake forecaster resolves every slot to a constant.
          expect(
            charges.map((charge) => charge.valueIncVat),
            everyElement(7.0),
          );
        },
      );

      test(
        'returns empty when no slot falls inside the window',
        () async {
          final forecastService = ForecastService(
            nesoApiClient: _client(
              embedded: [
                _embedded('2026-07-01', 1),
              ],
              wind: [
                _wind('2026-07-01', 1),
              ],
            ),
            priceForecastModelService: priceForecastModelService,
          );

          final charges = await forecastService.getForecastCharges(
            gsp: 'C',
            from: DateTime.utc(2026, 7, 2),
            to: DateTime.utc(2026, 7, 9),
          );

          expect(
            charges,
            isEmpty,
          );
        },
      );

      test(
        'returns the slots sorted ascending by validFrom',
        () async {
          final forecastService = ForecastService(
            nesoApiClient: _client(
              embedded: [
                _embedded('2026-07-01', 3),
                _embedded('2026-07-01', 1),
                _embedded('2026-07-01', 2),
              ],
              wind: [
                _wind('2026-07-01', 1),
                _wind('2026-07-01', 2),
                _wind('2026-07-01', 3),
              ],
            ),
            priceForecastModelService: priceForecastModelService,
          );

          final charges = await forecastService.getForecastCharges(
            gsp: 'C',
            from: DateTime.utc(2026, 6, 30, 23, 0),
            to: DateTime.utc(2026, 7, 1, 1, 0),
          );

          expect(
            charges.map((charge) => charge.validFrom),
            [
              DateTime.utc(2026, 6, 30, 23, 0),
              DateTime.utc(2026, 6, 30, 23, 30),
              DateTime.utc(2026, 7, 1, 0, 0),
            ],
          );
        },
      );

      test(
        'stamps slots as plain UTC DateTimes, not tz.TZDateTimes, during British Summer Time',
        () async {
          // British Summer Time, so 2026-07-01 period 1 (00:00 local) is
          // 2026-06-30T23:00:00Z and each later period is 30 minutes on.
          final forecastService = ForecastService(
            nesoApiClient: _client(
              embedded: [
                _embedded('2026-07-01', 1),
              ],
              wind: [
                _wind('2026-07-01', 1),
              ],
            ),
            priceForecastModelService: priceForecastModelService,
          );

          final charges = await forecastService.getForecastCharges(
            gsp: 'C',
            from: DateTime.utc(2026, 6, 30, 23, 0),
            to: DateTime.utc(2026, 7, 1, 1, 0),
          );

          // The instant is correct regardless of the type...
          expect(
            charges.single.validFrom,
            DateTime.utc(2026, 6, 30, 23, 0),
          );

          // ...but the type matters: a tz.TZDateTime resolves toLocal() against
          // the timezone package's tz.local (UTC by default), not the device's
          // system zone, so a forecast stored as one renders an hour off and
          // overlaps the confirmed prices on non-UTC devices. A confirmed
          // HistoricalCharge.validFrom is a plain DateTime, so the forecast must
          // match for the two series to line up.
          expect(
            charges.single.validFrom,
            isNot(isA<tz.TZDateTime>()),
          );
        },
      );

      test(
        'stamps slots as plain UTC DateTimes, not tz.TZDateTimes, during Greenwich Mean Time',
        () async {
          // Greenwich Mean Time, so 2026-01-01 period 1 (00:00 local) is
          // 2026-01-01T00:00:00Z and each later period is 30 minutes on. This is
          // the winter counterpart to the British Summer Time case above, where
          // the same period maps an hour earlier in UTC — the London offset the
          // service must apply differs by season.
          final forecastService = ForecastService(
            nesoApiClient: _client(
              embedded: [
                _embedded('2026-01-01', 1),
              ],
              wind: [
                _wind('2026-01-01', 1),
              ],
            ),
            priceForecastModelService: priceForecastModelService,
          );

          final charges = await forecastService.getForecastCharges(
            gsp: 'C',
            from: DateTime.utc(2025, 12, 31, 23, 0),
            to: DateTime.utc(2026, 1, 1, 1, 0),
          );

          // The instant is correct regardless of the type: in GMT period 1 maps
          // to the same day's midnight in UTC, an hour later than the BST case...
          expect(
            charges.single.validFrom,
            DateTime.utc(2026, 1, 1, 0, 0),
          );

          // ...but the type matters: a tz.TZDateTime resolves toLocal() against
          // the timezone package's tz.local (UTC by default), not the device's
          // system zone, so a forecast stored as one renders an hour off and
          // overlaps the confirmed prices on non-UTC devices. A confirmed
          // HistoricalCharge.validFrom is a plain DateTime, so the forecast must
          // match for the two series to line up.
          expect(
            charges.single.validFrom,
            isNot(isA<tz.TZDateTime>()),
          );
        },
      );
    },
  );
}
