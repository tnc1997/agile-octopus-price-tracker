import 'dart:async';
import 'dart:convert';

import 'package:agile_octopus_price_tracker/settings/tariff_form_card.dart';
import 'package:agile_octopus_price_tracker/welcome/welcome_card.dart';
import 'package:agile_octopus_price_tracker/welcome/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:nominatim_api_client/nominatim_api_client.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// An [http.Client] that dispatches based on [Uri.path], like
/// [MockClientAdapter] in `../helpers.dart`, but whose handlers may return
/// their [http.Response] either synchronously or via a [Future] — letting a
/// test control exactly when a given call resolves (e.g. to simulate a slow
/// first request resolving after a faster later one). Falls back to a 404
/// for any path with no matching handler.
class _FakeClient extends http.BaseClient {
  _FakeClient(this._handlers);

  final Map<String, FutureOr<http.Response> Function(http.Request request)>
      _handlers;

  @override
  Future<http.StreamedResponse> send(
    http.BaseRequest request,
  ) async {
    final handler = _handlers[request.url.path];

    final response = handler != null
        ? await handler(request as http.Request)
        : http.Response('Not Found', 404);

    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      request: request,
      headers: response.headers,
    );
  }
}

void main() {
  group(
    'WelcomeScreen',
    () {
      testWidgets(
        'renders a Continue button rather than a Save button',
        (tester) async {
          SharedPreferencesAsyncPlatform.instance =
              InMemorySharedPreferencesAsync.withData({
            'grid_supply_point_group_id': '_C',
            'import_product_code': 'AGILE-24-10-01',
          });

          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/welcome',
                routes: [
                  GoRoute(
                    path: '/welcome',
                    builder: (context, state) {
                      return MultiProvider(
                        providers: [
                          Provider<OctopusEnergyApiClient>.value(
                            value: OctopusEnergyApiClient(
                              client: _FakeClient(
                                {
                                  '/v1/industry/grid-supply-points/':
                                      (request) {
                                    return http.Response(
                                      json.encode({
                                        'count': 1,
                                        'next': null,
                                        'previous': null,
                                        'results': [
                                          {
                                            'group_id': '_C',
                                          },
                                        ],
                                      }),
                                      200,
                                    );
                                  },
                                },
                              ),
                            ),
                          ),
                          Provider<NominatimApiClient>.value(
                            value: NominatimApiClient(),
                          ),
                          Provider<SharedPreferencesAsync>.value(
                            value: SharedPreferencesAsync(),
                          ),
                        ],
                        child: const WelcomeScreen(),
                      );
                    },
                  ),
                ],
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.text('Continue'),
            findsOneWidget,
          );

          expect(
            find.text('Save'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'renders a WelcomeCard and a TariffFormCard',
        (tester) async {
          SharedPreferencesAsyncPlatform.instance =
              InMemorySharedPreferencesAsync.withData({
            'grid_supply_point_group_id': '_C',
            'import_product_code': 'AGILE-24-10-01',
          });

          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/welcome',
                routes: [
                  GoRoute(
                    path: '/welcome',
                    builder: (context, state) {
                      return MultiProvider(
                        providers: [
                          Provider<OctopusEnergyApiClient>.value(
                            value: OctopusEnergyApiClient(
                              client: _FakeClient(
                                {
                                  '/v1/industry/grid-supply-points/':
                                      (request) {
                                    return http.Response(
                                      json.encode({
                                        'count': 1,
                                        'next': null,
                                        'previous': null,
                                        'results': [
                                          {
                                            'group_id': '_C',
                                          },
                                        ],
                                      }),
                                      200,
                                    );
                                  },
                                },
                              ),
                            ),
                          ),
                          Provider<NominatimApiClient>.value(
                            value: NominatimApiClient(),
                          ),
                          Provider<SharedPreferencesAsync>.value(
                            value: SharedPreferencesAsync(),
                          ),
                        ],
                        child: const WelcomeScreen(),
                      );
                    },
                  ),
                ],
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.byType(WelcomeCard),
            findsOneWidget,
          );

          expect(
            find.byType(TariffFormCard),
            findsOneWidget,
          );
        },
      );
    },
  );
}
