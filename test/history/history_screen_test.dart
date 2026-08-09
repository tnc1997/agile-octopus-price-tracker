import 'dart:async';
import 'dart:convert';

import 'package:agile_octopus_price_tracker/history/historical_charge_chart_card.dart';
import 'package:agile_octopus_price_tracker/history/historical_charge_period_segmented_button.dart';
import 'package:agile_octopus_price_tracker/history/historical_charge_sliver_list.dart';
import 'package:agile_octopus_price_tracker/history/historical_charge_summary.dart';
import 'package:agile_octopus_price_tracker/history/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

/// Wraps [HistoryScreen] in a [MultiProvider] with the [OctopusEnergyApiClient]
/// and [SharedPreferencesAsync] it reads in `initState`, pre-seeding all three
/// tariff-lookup preferences so [getImportProductCodeAndImportTariffCode]
/// skips the network invocations and goes straight to fetching unit rates.
///
/// Grows the test surface's physical size to a tall viewport (restored by
/// [tester]'s teardown) rather than relying on `materialApp`'s `surfaceSize`,
/// which only overrides the ambient `MediaQuery.size` seen by descendants and
/// does not affect the actual viewport the `CustomScrollView` lays out
/// against; without a genuinely tall viewport the date-range/summary/chart
/// content pushes the sliver list below the fold, where it renders with a
/// zero paint extent and is invisible to `find.byType`.
///
/// Takes the [http.Client] directly (rather than a map of handlers) so
/// callers can pass either a [_FakeClient] or any other [http.Client].
Widget _createHistoryScreen(
  WidgetTester tester,
  http.Client client,
) {
  tester.view.physicalSize = const Size(1920, 2160);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.reset);

  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData({
    'grid_supply_point_group_id': '_C',
    'import_product_code': 'AGILE-24-10-01',
    'import_tariff_code': 'E-1R-AGILE-24-10-01-C',
  });

  return MaterialApp(
    home: Scaffold(
      body: MultiProvider(
        providers: [
          Provider<OctopusEnergyApiClient>.value(
            value: OctopusEnergyApiClient(
              client: client,
            ),
          ),
          Provider<SharedPreferencesAsync>.value(
            value: SharedPreferencesAsync(),
          ),
        ],
        child: const HistoryScreen(),
      ),
    ),
  );
}

void main() {
  group(
    'HistoryScreen',
    () {
      testWidgets(
        'ignores a slower earlier fetch that resolves after a faster later one',
        (tester) async {
          // Regression test for the `_generation` guard in `_load`. The
          // first fetch (sevenDays, triggered by initState) is held open via
          // `first`, a Completer this test controls directly — the
          // handler below awaits it before returning, standing in for a slow
          // network response. Selecting 30 days triggers a second fetch that
          // resolves immediately. Completing the FIRST (stale) response only
          // afterwards proves the guard discards it rather than overwriting
          // the fresher, already-shown data.
          final first = Completer<http.Response>();

          var invocations = 0;

          await tester.pumpWidget(
            _createHistoryScreen(
              tester,
              _FakeClient({
                '/v1/products/AGILE-24-10-01/electricity-tariffs/E-1R-AGILE-24-10-01-C/standard-unit-rates/':
                    (request) {
                  invocations++;

                  if (invocations == 1) {
                    return first.future;
                  }

                  final historicalCharges = [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: 10.0,
                      valueIncVat: 10.0,
                    ),
                  ];

                  return http.Response(
                    json.encode({
                      'count': historicalCharges.length,
                      'next': null,
                      'previous': null,
                      'results': historicalCharges.map((e) => e.toJson()).toList(),
                    }),
                    200,
                  );
                },
              }),
            ),
          );

          await tester.pump();

          // The first fetch is still pending (its Completer hasn't resolved),
          // so this is still showing the initial loading spinner.
          expect(
            find.byType(CircularProgressIndicator),
            findsOneWidget,
          );

          await tester.tap(
            find.text('30 days'),
          );

          await tester.pumpAndSettle();

          // The second (30 days) fetch resolved immediately, so its data is
          // already showing, even though the first fetch hasn't completed.
          expect(
            find.text('10.00'),
            findsWidgets,
          );

          expect(
            invocations,
            2,
          );

          // Now let the stale first fetch resolve, with data that must NOT
          // clobber what's already shown.
          final historicalCharges = [
            HistoricalCharge(
              validFrom: DateTime.utc(1970),
              validTo: DateTime.utc(1970, 1, 1, 0, 30),
              valueExcVat: 999.0,
              valueIncVat: 999.0,
            ),
          ];

          first.complete(
            http.Response(
              json.encode({
                'count': historicalCharges.length,
                'next': null,
                'previous': null,
                'results': historicalCharges.map((e) => e.toJson()).toList(),
              }),
              200,
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.text('10.00'),
            findsWidgets,
          );

          expect(
            find.text('999.00'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'opens a DateRangePickerDialog when the date range ListTile is tapped',
        (tester) async {
          await tester.pumpWidget(
            _createHistoryScreen(
              tester,
              _FakeClient({
                '/v1/products/AGILE-24-10-01/electricity-tariffs/E-1R-AGILE-24-10-01-C/standard-unit-rates/':
                    (request) {
                  return http.Response(
                    json.encode({
                      'count': 0,
                      'next': null,
                      'previous': null,
                      'results': [],
                    }),
                    200,
                  );
                },
              }),
            ),
          );

          await tester.pumpAndSettle();

          await tester.tap(
            find.byType(ListTile),
          );

          await tester.pumpAndSettle();

          expect(
            find.byType(DateRangePickerDialog),
            findsOneWidget,
          );

          Navigator.of(
            tester.element(
              find.byType(DateRangePickerDialog),
            ),
          ).pop();

          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'refetches for a custom date range chosen via the date range picker and deselects the period',
        (tester) async {
          late Uri last;

          await tester.pumpWidget(
            _createHistoryScreen(
              tester,
              _FakeClient({
                '/v1/products/AGILE-24-10-01/electricity-tariffs/E-1R-AGILE-24-10-01-C/standard-unit-rates/':
                    (request) {
                  last = request.url;

                  return http.Response(
                    json.encode({
                      'count': 0,
                      'next': null,
                      'previous': null,
                      'results': [],
                    }),
                    200,
                  );
                },
              }),
            ),
          );

          await tester.pumpAndSettle();

          await tester.tap(
            find.byType(ListTile),
          );

          await tester.pumpAndSettle();

          // The picker defaults to calendar entry mode; switching to input
          // mode lets a custom range be typed directly rather than having to
          // tap specific day cells, whose visible month(s) shift depending
          // on what day it is when the suite runs.
          await tester.tap(
            find.byIcon(Icons.edit_outlined),
          );

          await tester.pumpAndSettle();

          await tester.enterText(
            find.byType(TextField).at(0),
            '06/01/2024',
          );

          await tester.enterText(
            find.byType(TextField).at(1),
            '06/10/2024',
          );

          await tester.pumpAndSettle();

          await tester.tap(
            find.text('OK'),
          );

          await tester.pumpAndSettle();

          expect(
            last.queryParameters['period_from'],
            DateTime(2024, 6, 1).toIso8601String(),
          );

          expect(
            last.queryParameters['period_to'],
            DateTime(2024, 6, 11).toIso8601String(),
          );

          final button = tester.widget<HistoricalChargePeriodSegmentedButton>(
            find.byType(HistoricalChargePeriodSegmentedButton),
          );

          expect(
            button.selected,
            isNull,
          );
        },
      );

      testWidgets(
        'refetches with a distinct page of data when a different HistoricalChargePeriodSegmentedButton segment is selected',
        (tester) async {
          // The fake unit-rates response grows by one slot on each call, so
          // the sliver list's item count is a proxy for which call last
          // resolved: a change means the tap below triggered a genuinely new
          // fetch rather than reusing the first one's result.
          //
          // Asserting an intermediate loading spinner here would be flaky:
          // the fake client resolves synchronously, so the whole refetch can
          // complete within the single pump a tap needs to be recognized,
          // leaving no frame where the spinner is guaranteed to still be up.
          var invocations = 0;

          await tester.pumpWidget(
            _createHistoryScreen(
              tester,
              _FakeClient({
                '/v1/products/AGILE-24-10-01/electricity-tariffs/E-1R-AGILE-24-10-01-C/standard-unit-rates/':
                    (request) {
                  invocations++;

                  final historicalCharges = [
                    for (var i = 0; i < invocations; i++)
                      HistoricalCharge(
                        validFrom: DateTime.utc(1970).add(
                          Duration(
                            minutes: i * 30,
                          ),
                        ),
                        validTo: DateTime.utc(1970).add(
                          Duration(
                            minutes: i * 30 + 30,
                          ),
                        ),
                        valueExcVat: 10.0,
                        valueIncVat: 10.0,
                      ),
                  ];

                  return http.Response(
                    json.encode({
                      'count': historicalCharges.length,
                      'next': null,
                      'previous': null,
                      'results': historicalCharges.map((e) => e.toJson()).toList(),
                    }),
                    200,
                  );
                },
              }),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.byType(HistoricalChargeSliverList),
            findsOneWidget,
          );

          expect(
            invocations,
            1,
          );

          await tester.tap(
            find.text('30 days'),
          );

          await tester.pumpAndSettle();

          expect(
            find.byType(HistoricalChargeSliverList),
            findsOneWidget,
          );

          expect(
            invocations,
            2,
          );
        },
      );

      testWidgets(
        'requests the query date range matching each selected HistoricalChargePeriod',
        (tester) async {
          late Uri last;

          await tester.pumpWidget(
            _createHistoryScreen(
              tester,
              _FakeClient({
                '/v1/products/AGILE-24-10-01/electricity-tariffs/E-1R-AGILE-24-10-01-C/standard-unit-rates/':
                    (request) {
                  last = request.url;

                  return http.Response(
                    json.encode({
                      'count': 0,
                      'next': null,
                      'previous': null,
                      'results': [],
                    }),
                    200,
                  );
                },
              }),
            ),
          );

          await tester.pumpAndSettle();

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          void expectRangeMatches(
            DateTimeRange range,
          ) {
            expect(
              last.queryParameters['period_from'],
              range.start.toIso8601String(),
            );

            expect(
              last.queryParameters['period_to'],
              range.end.add(const Duration(days: 1)).toIso8601String(),
            );
          }

          expectRangeMatches(
            DateTimeRange(
              start: today.subtract(
                const Duration(
                  days: 6,
                ),
              ),
              end: today,
            ),
          );

          await tester.tap(
            find.text('30 days'),
          );

          await tester.pumpAndSettle();

          expectRangeMatches(
            DateTimeRange(
              start: today.subtract(
                const Duration(
                  days: 29,
                ),
              ),
              end: today,
            ),
          );

          await tester.tap(
            find.text('3 months'),
          );

          await tester.pumpAndSettle();

          expectRangeMatches(
            DateTimeRange(
              start: DateTime(today.year, today.month - 3, today.day),
              end: today,
            ),
          );

          await tester.tap(
            find.text('12 months'),
          );

          await tester.pumpAndSettle();

          expectRangeMatches(
            DateTimeRange(
              start: DateTime(today.year - 1, today.month, today.day),
              end: today,
            ),
          );
        },
      );

      testWidgets(
        'shows HistoricalChargeSummary, HistoricalChargeChartCard and HistoricalChargeSliverList for a non-empty charge list',
        (tester) async {
          await tester.pumpWidget(
            _createHistoryScreen(
              tester,
              _FakeClient({
                '/v1/products/AGILE-24-10-01/electricity-tariffs/E-1R-AGILE-24-10-01-C/standard-unit-rates/':
                    (request) {
                  final historicalCharges = [
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970),
                      validTo: DateTime.utc(1970, 1, 1, 0, 30),
                      valueExcVat: 10.0,
                      valueIncVat: 10.0,
                    ),
                    HistoricalCharge(
                      validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                      validTo: DateTime.utc(1970, 1, 1, 1, 0),
                      valueExcVat: 20.0,
                      valueIncVat: 20.0,
                    ),
                  ];

                  return http.Response(
                    json.encode({
                      'count': historicalCharges.length,
                      'next': null,
                      'previous': null,
                      'results': historicalCharges.map((e) => e.toJson()).toList(),
                    }),
                    200,
                  );
                },
              }),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.byType(HistoricalChargeSummary),
            findsOneWidget,
          );

          expect(
            find.byType(HistoricalChargeChartCard),
            findsOneWidget,
          );

          expect(
            find.descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(HistoricalChargeSliverList),
            ),
            findsOneWidget,
          );

          expect(
            find.text('No data for the selected range.'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'shows a loading spinner while the initial fetch is pending',
        (tester) async {
          await tester.pumpWidget(
            _createHistoryScreen(
              tester,
              _FakeClient({
                '/v1/products/AGILE-24-10-01/electricity-tariffs/E-1R-AGILE-24-10-01-C/standard-unit-rates/':
                    (request) {
                  return http.Response(
                    json.encode({
                      'count': 0,
                      'next': null,
                      'previous': null,
                      'results': [],
                    }),
                    200,
                  );
                },
              }),
            ),
          );

          expect(
            find.byType(CircularProgressIndicator),
            findsOneWidget,
          );

          expect(
            find.byType(HistoricalChargeSliverList),
            findsNothing,
          );

          expect(
            find.text('No data for the selected range.'),
            findsNothing,
          );

          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'shows the no data message when the API returns an empty charge list',
        (tester) async {
          await tester.pumpWidget(
            _createHistoryScreen(
              tester,
              _FakeClient({
                '/v1/products/AGILE-24-10-01/electricity-tariffs/E-1R-AGILE-24-10-01-C/standard-unit-rates/':
                    (request) {
                  return http.Response(
                    json.encode({
                      'count': 0,
                      'next': null,
                      'previous': null,
                      'results': [],
                    }),
                    200,
                  );
                },
              }),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.text('No data for the selected range.'),
            findsOneWidget,
          );

          expect(
            find.byType(HistoricalChargeSliverList),
            findsNothing,
          );
        },
      );

      testWidgets(
        'shows the no data message when the API returns an error status',
        (tester) async {
          await tester.pumpWidget(
            _createHistoryScreen(
              tester,
              _FakeClient({
                '/v1/products/AGILE-24-10-01/electricity-tariffs/E-1R-AGILE-24-10-01-C/standard-unit-rates/':
                    (request) {
                  return http.Response(
                    'Service Unavailable',
                    503,
                  );
                },
              }),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.text('No data for the selected range.'),
            findsOneWidget,
          );

          expect(
            find.byType(HistoricalChargeSliverList),
            findsNothing,
          );
        },
      );
    },
  );
}
