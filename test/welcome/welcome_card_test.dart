import 'package:agile_octopus_price_tracker/welcome/welcome_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'WelcomeCard',
    () {
      testWidgets(
        'renders the headline',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const WelcomeCard(),
              ),
            ),
          );

          expect(
            find.text(
              'Welcome to Price Tracker for Agile Octopus',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders the subtitle',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const WelcomeCard(),
              ),
            ),
          );

          expect(
            find.text(
              'Let\'s get you set up to track your Agile Octopus prices.',
            ),
            findsOneWidget,
          );
        },
      );
    },
  );
}
