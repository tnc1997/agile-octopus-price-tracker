import 'package:agile_octopus_price_tracker/settings/color_stops_form.dart';
import 'package:agile_octopus_price_tracker/settings/color_stops_form_card.dart';
import 'package:agile_octopus_price_tracker/settings/settings_card_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group(
    'ColorStopsFormCard',
    () {
      testWidgets(
        'renders a Card containing a SettingsCardHeader titled "Price colour thresholds" and a ColorStopsForm',
        (tester) async {
          SharedPreferencesAsyncPlatform.instance =
              InMemorySharedPreferencesAsync.withData({});

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                Provider<SharedPreferencesAsync>.value(
                  value: SharedPreferencesAsync(),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: const ColorStopsFormCard(),
                ),
              ),
            ),
          );

          await tester.pump();

          expect(
            find.byType(Card),
            findsOneWidget,
          );

          expect(
            find.descendant(
              of: find.byType(Card),
              matching: find.byType(SettingsCardHeader),
            ),
            findsOneWidget,
          );

          expect(
            find.descendant(
              of: find.byType(Card),
              matching: find.byType(ColorStopsForm),
            ),
            findsOneWidget,
          );

          expect(
            find.text('Price colour thresholds'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
