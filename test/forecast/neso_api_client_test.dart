import 'dart:convert';

import 'package:agile_octopus_price_tracker/forecast/neso_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest.dart';

/// A CKAN `datastore_search` response carrying [records] under the standard
/// `success`/`result` envelope the client unwraps.
String _response(List<Map<String, dynamic>> records) {
  return json.encode({
    'success': true,
    'result': {
      'records': records,
    },
  });
}

void main() {
  group(
    'NesoApiClient',
    () {
      setUpAll(
        () {
          initializeTimeZones();
        },
      );

      test(
        'parses the embedded solar and wind forecast',
        () async {
          final client = NesoApiClient(
            client: MockClient((request) async {
              // The embedded resource spells its date as a timestamp, which the
              // client trims to YYYY-MM-DD, and may type a column as a string.
              return http.Response(
                _response([
                  {
                    'SETTLEMENT_DATE': '2026-06-29T00:00:00',
                    'SETTLEMENT_PERIOD': 31,
                    'EMBEDDED_WIND_FORECAST': 1439,
                    'EMBEDDED_SOLAR_FORECAST': '9502',
                  },
                ]),
                200,
              );
            }),
          );

          final forecasts = await client.getEmbeddedSolarAndWindForecast();

          expect(
            forecasts,
            hasLength(1),
          );

          expect(
            forecasts.single.settlementDate,
            '2026-06-29',
          );

          expect(
            forecasts.single.settlementPeriod,
            31,
          );

          expect(
            forecasts.single.embeddedWindForecastMw,
            1439.0,
          );

          expect(
            forecasts.single.embeddedSolarForecastMw,
            9502.0,
          );
        },
      );

      test(
        'parses the wind forecast',
        () async {
          final client = NesoApiClient(
            client: MockClient((request) async {
              return http.Response(
                _response([
                  {
                    'Date': '2026-06-29',
                    'Settlement_Period': 28,
                    'Wind_Forecast': 6900,
                  },
                ]),
                200,
              );
            }),
          );

          final forecasts = await client.getFourteenDaysAheadWindForecast();

          expect(
            forecasts,
            hasLength(1),
          );

          expect(
            forecasts.single.settlementDate,
            '2026-06-29',
          );

          expect(
            forecasts.single.settlementPeriod,
            28,
          );

          expect(
            forecasts.single.windForecastMw,
            6900.0,
          );
        },
      );

      test(
        'requests the resource by id with a row limit',
        () async {
          late final Uri url;

          final client = NesoApiClient(
            client: MockClient((request) async {
              url = request.url;
              return http.Response(_response([]), 200);
            }),
          );

          await client.getFourteenDaysAheadWindForecast();

          expect(
            url.path,
            '/api/3/action/datastore_search',
          );

          expect(
            url.queryParameters['resource_id'],
            '93c3048e-1dab-4057-a2a9-417540583929',
          );

          expect(
            url.queryParameters['limit'],
            '1000',
          );
        },
      );

      test(
        'throws when CKAN reports failure',
        () async {
          final client = NesoApiClient(
            client: MockClient((request) async {
              return http.Response(
                json.encode({'success': false}),
                200,
              );
            }),
          );

          expect(
            client.getEmbeddedSolarAndWindForecast(),
            throwsA(isA<http.ClientException>()),
          );
        },
      );

      test(
        'throws when the response is not 200',
        () async {
          final client = NesoApiClient(
            client: MockClient((request) async {
              return http.Response('Service Unavailable', 503);
            }),
          );

          expect(
            client.getFourteenDaysAheadWindForecast(),
            throwsA(isA<http.ClientException>()),
          );
        },
      );
    },
  );
}
