import 'package:agile_octopus_price_tracker/settings/about_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// A [UrlLauncherPlatform] mock. `PlatformInterface.verify` (called by
/// `UrlLauncherPlatform.instance=`) rejects plain `implements`-based mocks at
/// runtime, so this also mixes in [MockPlatformInterfaceMixin], which exists
/// specifically to satisfy that check for tests.
class _MockUrlLauncherPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

void main() {
  setUpAll(() {
    registerFallbackValue(const LaunchOptions());
  });

  group(
    'AboutButton',
    () {
      testWidgets(
        'does not launch a link\'s url when canLaunchUrl returns false',
        (tester) async {
          final platform = _MockUrlLauncherPlatform();

          when(() {
            return platform.canLaunch(any());
          }).thenAnswer(
            (_) async {
              return false;
            },
          );

          UrlLauncherPlatform.instance = platform;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const AboutButton(),
              ),
            ),
          );

          await tester.tap(
            find.text('About Price Tracker for Agile Octopus'),
          );

          await tester.pumpAndSettle();

          await tester.tapOnText(
            find.textRange.ofSubstring('Octopus Energy'),
          );

          await tester.pumpAndSettle();

          verify(
            () {
              return platform.canLaunch(
                'https://octopus.energy',
              );
            },
          ).called(1);

          verifyNever(
            () {
              return platform.launchUrl(any(), any());
            },
          );
        },
      );

      testWidgets(
        'opens the ODbL license url when its link is tapped',
        (tester) async {
          final platform = _MockUrlLauncherPlatform();

          when(() {
            return platform.canLaunch(any());
          }).thenAnswer(
            (_) async {
              return true;
            },
          );

          when(() {
            return platform.launchUrl(any(), any());
          }).thenAnswer(
            (_) async {
              return true;
            },
          );

          UrlLauncherPlatform.instance = platform;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const AboutButton(),
              ),
            ),
          );

          await tester.tap(
            find.text('About Price Tracker for Agile Octopus'),
          );

          await tester.pumpAndSettle();

          await tester.tapOnText(
            find.textRange.ofSubstring('Open Database License (ODbL)'),
          );

          await tester.pumpAndSettle();

          verify(
            () {
              return platform.launchUrl(
                'https://opendatacommons.org/licenses/odbl',
                any(),
              );
            },
          ).called(1);
        },
      );

      testWidgets(
        'opens the Octopus Energy url when its link is tapped',
        (tester) async {
          final platform = _MockUrlLauncherPlatform();

          when(() {
            return platform.canLaunch(any());
          }).thenAnswer(
            (_) async {
              return true;
            },
          );

          when(() {
            return platform.launchUrl(any(), any());
          }).thenAnswer(
            (_) async {
              return true;
            },
          );

          UrlLauncherPlatform.instance = platform;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const AboutButton(),
              ),
            ),
          );

          await tester.tap(
            find.text('About Price Tracker for Agile Octopus'),
          );

          await tester.pumpAndSettle();

          await tester.tapOnText(
            find.textRange.ofSubstring('Octopus Energy'),
          );

          await tester.pumpAndSettle();

          verify(
            () {
              return platform.launchUrl(
                'https://octopus.energy',
                any(),
              );
            },
          ).called(1);
        },
      );

      testWidgets(
        'opens the OpenStreetMap url when its link is tapped',
        (tester) async {
          final platform = _MockUrlLauncherPlatform();

          when(() {
            return platform.canLaunch(any());
          }).thenAnswer(
            (_) async {
              return true;
            },
          );

          when(() {
            return platform.launchUrl(any(), any());
          }).thenAnswer(
            (_) async {
              return true;
            },
          );

          UrlLauncherPlatform.instance = platform;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const AboutButton(),
              ),
            ),
          );

          await tester.tap(
            find.text('About Price Tracker for Agile Octopus'),
          );

          await tester.pumpAndSettle();

          await tester.tapOnText(
            find.textRange.ofSubstring('OpenStreetMap'),
          );

          await tester.pumpAndSettle();

          verify(
            () {
              return platform.launchUrl(
                'https://openstreetmap.org/copyright',
                any(),
              );
            },
          ).called(1);
        },
      );

      testWidgets(
        'renders a button labeled "About Price Tracker for Agile Octopus"',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const AboutButton(),
              ),
            ),
          );

          expect(
            find.widgetWithText(
              TextButton,
              'About Price Tracker for Agile Octopus',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows an about dialog with the app name and version when tapped',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const AboutButton(),
              ),
            ),
          );

          await tester.tap(
            find.text('About Price Tracker for Agile Octopus'),
          );

          await tester.pumpAndSettle();

          expect(
            find.byType(AboutDialog),
            findsOneWidget,
          );

          expect(
            find.text('Price Tracker for Agile Octopus'),
            findsOneWidget,
          );

          expect(
            find.textContaining('0.7.0'),
            findsOneWidget,
          );

          expect(
            find.textContaining('Copyright (c) 2026 Thomas Clark'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows the Octopus Energy, OpenStreetMap and ODbL attribution text when tapped',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const AboutButton(),
              ),
            ),
          );

          await tester.tap(
            find.text('About Price Tracker for Agile Octopus'),
          );

          await tester.pumpAndSettle();

          expect(
            find.textContaining('Data provided by'),
            findsOneWidget,
          );

          expect(
            find.textContaining(
              'who do not endorse this unofficial application',
            ),
            findsOneWidget,
          );

          expect(
            find.textContaining('Geocoding provided by'),
            findsOneWidget,
          );

          expect(
            find.textContaining('Open Database License (ODbL)'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
