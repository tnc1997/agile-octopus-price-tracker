import 'package:agile_octopus_price_tracker/common/shell_bottom_navigation_bar.dart';
import 'package:agile_octopus_price_tracker/common/shell_navigation_rail.dart';
import 'package:agile_octopus_price_tracker/common/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group(
    'ShellScreen',
    () {
      testWidgets(
        'hides ShellBottomNavigationBar and shows ShellNavigationRail at width 993 (the width exceeds 992)',
        (tester) async {
          tester.view.physicalSize = const Size(993, 1080);
          tester.view.devicePixelRatio = 1.0;

          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) {
                      return const ShellScreen(
                        child: Text('Body'),
                      );
                    },
                  ),
                ],
              ),
            ),
          );

          expect(
            find.byType(ShellNavigationRail),
            findsOneWidget,
          );

          expect(
            find.byType(ShellBottomNavigationBar),
            findsNothing,
          );
        },
      );

      testWidgets(
        'hides ShellBottomNavigationBar and shows ShellNavigationRail for a wide viewport',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 1080);
          tester.view.devicePixelRatio = 1.0;

          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) {
                      return const ShellScreen(
                        child: Text('Body'),
                      );
                    },
                  ),
                ],
              ),
            ),
          );

          expect(
            find.byType(ShellNavigationRail),
            findsOneWidget,
          );

          expect(
            find.byType(ShellBottomNavigationBar),
            findsNothing,
          );
        },
      );

      testWidgets(
        'hides ShellNavigationRail and shows ShellBottomNavigationBar at width 992 (the width does not exceed 992)',
        (tester) async {
          tester.view.physicalSize = const Size(992, 1080);
          tester.view.devicePixelRatio = 1.0;

          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) {
                      return const ShellScreen(
                        child: Text('Body'),
                      );
                    },
                  ),
                ],
              ),
            ),
          );

          expect(
            find.byType(ShellBottomNavigationBar),
            findsOneWidget,
          );

          expect(
            find.byType(ShellNavigationRail),
            findsNothing,
          );
        },
      );

      testWidgets(
        'hides ShellNavigationRail and shows ShellBottomNavigationBar for a narrow viewport',
        (tester) async {
          tester.view.physicalSize = const Size(400, 1080);
          tester.view.devicePixelRatio = 1.0;

          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) {
                      return const ShellScreen(
                        child: Text('Body'),
                      );
                    },
                  ),
                ],
              ),
            ),
          );

          expect(
            find.byType(ShellBottomNavigationBar),
            findsOneWidget,
          );

          expect(
            find.byType(ShellNavigationRail),
            findsNothing,
          );
        },
      );
    },
  );
}
