import 'dart:convert';

import 'package:agile_octopus_price_tracker/forecast/forecast_service.dart';
import 'package:agile_octopus_price_tracker/forecast/neso_api_client.dart';
import 'package:agile_octopus_price_tracker/forecast/price_forecast_model_service.dart';
import 'package:agile_octopus_price_tracker/home/historical_charge_chart_card.dart';
import 'package:agile_octopus_price_tracker/home/historical_charge_todays_summary_card.dart';
import 'package:agile_octopus_price_tracker/home/historical_charge_window_wrap.dart';
import 'package:agile_octopus_price_tracker/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest.dart';

/// An [http.Client] that dispatches based on [Uri.path], for tests that need
/// more than one canned endpoint behind a single [OctopusEnergyApiClient]/
/// [NesoApiClient] (e.g. the multi-step tariff lookup flow). Falls back to a
/// 404 for any path with no matching handler.
class _FakeClient extends http.BaseClient {
  _FakeClient(this._handlers);

  final Map<String, http.Response Function(http.Request request)> _handlers;

  @override
  Future<http.StreamedResponse> send(
    http.BaseRequest request,
  ) async {
    final handler = _handlers[request.url.path];

    final response = handler != null
        ? handler(request as http.Request)
        : http.Response('Not Found', 404);

    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

/// A [PriceForecastModelService] test double whose `predict` is never
/// exercised here (the mocked NESO feeds below are empty, so no slot is ever
/// matched to forecast), matching the pattern in
/// `test/forecast/forecast_service_test.dart`.
class _FakePriceForecastModelService extends Fake
    implements PriceForecastModelService {}

/// Wraps [HomeScreen] with an [OctopusEnergyApiClient] whose unit-rates
/// endpoint returns [charges], a [SharedPreferencesAsync] seeded so
/// `getImportProductCodeAndImportTariffCode` skips the network round-trip
/// entirely, and no [ForecastService] (its sub-tree just spins forever,
/// which does not block the rest of the screen from rendering).
Widget _createHomeScreen(
  List<HistoricalCharge> charges,
) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData({
    'grid_supply_point_group_id': '_A',
    'import_product_code': 'product-code',
    'import_tariff_code': 'tariff-code',
  });

  return MultiProvider(
    providers: [
      Provider<OctopusEnergyApiClient>.value(
        value: OctopusEnergyApiClient(
          client: _FakeClient(
            {
              '/v1/products/product-code/electricity-tariffs/tariff-code/standard-unit-rates/':
                  (request) {
                return http.Response(
                  json.encode({
                    'count': charges.length,
                    'next': null,
                    'previous': null,
                    'results': charges.map((e) => e.toJson()).toList(),
                  }),
                  200,
                );
              },
            },
          ),
        ),
      ),
      Provider<SharedPreferencesAsync>.value(
        value: SharedPreferencesAsync(),
      ),
      Provider<ForecastService?>.value(
        value: null,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: const HomeScreen(),
      ),
    ),
  );
}

void main() {
  group(
    'HomeScreen',
    () {
      setUpAll(
        () {
          initializeTimeZones();
        },
      );

      testWidgets(
        'renders HistoricalChargeChartCard once a non-null ForecastService resolves an empty forecast',
        (tester) async {
          final charges = [
            HistoricalCharge(
              validFrom: DateTime.now().toUtc().add(
                    Duration(
                      minutes: (0.1 * 60).round(),
                    ),
                  ),
              validTo: DateTime.now().toUtc().add(
                    Duration(
                      minutes: (0.1 * 60).round() + 30,
                    ),
                  ),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          SharedPreferencesAsyncPlatform.instance =
              InMemorySharedPreferencesAsync.withData({
            'grid_supply_point_group_id': '_A',
            'import_product_code': 'product-code',
            'import_tariff_code': 'tariff-code',
          });

          // A real, non-null ForecastService backed by a NesoApiClient whose
          // embedded/wind feeds are both empty — so `_getForecastCharges`
          // genuinely calls through the forecast machinery (rather than
          // skipping it entirely, as every other test in this file does via
          // a null ForecastService) and resolves to an empty forecast,
          // letting HistoricalChargeChartCard actually render.
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                Provider<OctopusEnergyApiClient>.value(
                  value: OctopusEnergyApiClient(
                    client: _FakeClient(
                      {
                        '/v1/products/product-code/electricity-tariffs/tariff-code/standard-unit-rates/':
                            (request) {
                          return http.Response(
                            json.encode({
                              'count': charges.length,
                              'next': null,
                              'previous': null,
                              'results':
                                  charges.map((e) => e.toJson()).toList(),
                            }),
                            200,
                          );
                        },
                      },
                    ),
                  ),
                ),
                Provider<SharedPreferencesAsync>.value(
                  value: SharedPreferencesAsync(),
                ),
                Provider<ForecastService?>.value(
                  value: ForecastService(
                    nesoApiClient: NesoApiClient(
                      client: MockClient((request) async {
                        return http.Response(
                          json.encode({
                            'success': true,
                            'result': {
                              'records': <Map<String, dynamic>>[],
                            },
                          }),
                          200,
                        );
                      }),
                    ),
                    priceForecastModelService: _FakePriceForecastModelService(),
                  ),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: const HomeScreen(),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.byType(HistoricalChargeChartCard),
            findsOneWidget,
          );

          final card = tester.widget<HistoricalChargeChartCard>(
            find.byType(HistoricalChargeChartCard),
          );

          expect(
            card.forecastCharges,
            isEmpty,
          );

          expect(
            find.byType(CircularProgressIndicator),
            findsNothing,
          );
        },
      );

      testWidgets(
        'shows HistoricalChargeTodaysSummaryCard once an empty charge-list response resolves',
        (tester) async {
          await tester.pumpWidget(
            _createHomeScreen(
              [],
            ),
          );

          // The forecast section's FutureBuilder never resolves with a null
          // ForecastService, so pumpAndSettle would time out; bounded pumps
          // let the rest of the tree finish instead.
          for (var i = 0; i < 10; i++) {
            await tester.pump(
              const Duration(
                milliseconds: 100,
              ),
            );
          }

          expect(
            find.byType(HistoricalChargeTodaysSummaryCard),
            findsOneWidget,
          );

          expect(
            find.byType(CircularProgressIndicator),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows HistoricalChargeWindowWrap and HistoricalChargeTodaysSummaryCard with data derived from a non-empty charge list spanning today',
        (tester) async {
          await tester.pumpWidget(
            _createHomeScreen(
              [
                // Small positive offsets so all three slots fall on today's
                // local calendar day even when the test runs close to
                // midnight.
                HistoricalCharge(
                  validFrom: DateTime.now().toUtc().add(
                        Duration(
                          minutes: (0.1 * 60).round(),
                        ),
                      ),
                  validTo: DateTime.now().toUtc().add(
                        Duration(
                          minutes: (0.1 * 60).round() + 30,
                        ),
                      ),
                  valueExcVat: 20.0,
                  valueIncVat: 20.0,
                ),
                HistoricalCharge(
                  validFrom: DateTime.now().toUtc().add(
                        Duration(
                          minutes: (0.2 * 60).round(),
                        ),
                      ),
                  validTo: DateTime.now().toUtc().add(
                        Duration(
                          minutes: (0.2 * 60).round() + 30,
                        ),
                      ),
                  valueExcVat: 30.0,
                  valueIncVat: 30.0,
                ),
                HistoricalCharge(
                  validFrom: DateTime.now().toUtc().add(
                        Duration(
                          minutes: (0.3 * 60).round(),
                        ),
                      ),
                  validTo: DateTime.now().toUtc().add(
                        Duration(
                          minutes: (0.3 * 60).round() + 30,
                        ),
                      ),
                  valueExcVat: 40.0,
                  valueIncVat: 40.0,
                ),
              ],
            ),
          );

          for (var i = 0; i < 10; i++) {
            await tester.pump(
              const Duration(
                milliseconds: 100,
              ),
            );
          }

          expect(
            find.byType(HistoricalChargeWindowWrap),
            findsOneWidget,
          );

          expect(
            find.byType(HistoricalChargeTodaysSummaryCard),
            findsOneWidget,
          );

          // With no ForecastService provided, `context.watch<ForecastService?>()`
          // is always null so the forecast chart's FutureBuilder never
          // resolves and keeps spinning — harmlessly, alongside the rest of
          // the screen above having already rendered.
          expect(
            find.byType(HistoricalChargeChartCard),
            findsNothing,
          );

          expect(
            find.byType(CircularProgressIndicator),
            findsOneWidget,
          );

          // Today's summary averages the three slots: (20 + 30 + 40) / 3 = 30.
          expect(
            find.text('30.00'),
            findsWidgets,
          );
        },
      );

      testWidgets(
        'shows a CircularProgressIndicator while the initial fetch is pending',
        (tester) async {
          await tester.pumpWidget(
            _createHomeScreen(
              [],
            ),
          );

          await tester.pump();

          expect(
            find.byType(CircularProgressIndicator),
            findsOneWidget,
          );
        },
      );
    },
  );
}
