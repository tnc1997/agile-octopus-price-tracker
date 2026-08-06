import 'package:agile_octopus_price_tracker/common/shell_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group(
    'ShellNavigationRail',
    () {
      testWidgets(
        'navigates to / when the Home destination is tapped',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/history',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) {
                      return const Text('Home');
                    },
                  ),
                  GoRoute(
                    path: '/history',
                    builder: (context, state) {
                      return const ShellNavigationRail();
                    },
                  ),
                ],
              ),
            ),
          );

          await tester.tap(
            find.text('Home'),
          );

          await tester.pumpAndSettle();

          expect(
            find.text('Home'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'navigates to /history when the History destination is tapped',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) {
                      return const ShellNavigationRail();
                    },
                  ),
                  GoRoute(
                    path: '/history',
                    builder: (context, state) {
                      return const Text('History');
                    },
                  ),
                ],
              ),
            ),
          );

          await tester.tap(
            find.text('History'),
          );

          await tester.pumpAndSettle();

          expect(
            find.text('History'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'navigates to /settings when the Settings destination is tapped',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) {
                      return const ShellNavigationRail();
                    },
                  ),
                  GoRoute(
                    path: '/settings',
                    builder: (context, state) {
                      return const Text('Settings');
                    },
                  ),
                ],
              ),
            ),
          );

          await tester.tap(
            find.text('Settings'),
          );

          await tester.pumpAndSettle();

          expect(
            find.text('Settings'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'selects index 0 for an unknown path',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/welcome',
                routes: [
                  GoRoute(
                    path: '/welcome',
                    builder: (context, state) {
                      return const ShellNavigationRail();
                    },
                  ),
                ],
              ),
            ),
          );

          final navigationRail = tester.widget<NavigationRail>(
            find.byType(NavigationRail),
          );

          expect(
            navigationRail.selectedIndex,
            0,
          );
        },
      );

      testWidgets(
        'selects index 0 for path /',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) {
                      return const ShellNavigationRail();
                    },
                  ),
                ],
              ),
            ),
          );

          final navigationRail = tester.widget<NavigationRail>(
            find.byType(NavigationRail),
          );

          expect(
            navigationRail.selectedIndex,
            0,
          );
        },
      );

      testWidgets(
        'selects index 1 for path /history',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/history',
                routes: [
                  GoRoute(
                    path: '/history',
                    builder: (context, state) {
                      return const ShellNavigationRail();
                    },
                  ),
                ],
              ),
            ),
          );

          final navigationRail = tester.widget<NavigationRail>(
            find.byType(NavigationRail),
          );

          expect(
            navigationRail.selectedIndex,
            1,
          );
        },
      );

      testWidgets(
        'selects index 2 for path /settings',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/settings',
                routes: [
                  GoRoute(
                    path: '/settings',
                    builder: (context, state) {
                      return const ShellNavigationRail();
                    },
                  ),
                ],
              ),
            ),
          );

          final navigationRail = tester.widget<NavigationRail>(
            find.byType(NavigationRail),
          );

          expect(
            navigationRail.selectedIndex,
            2,
          );
        },
      );
    },
  );
}
