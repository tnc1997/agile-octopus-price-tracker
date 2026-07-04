import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import 'shell_screen.dart';

part 'shell_route.g.dart';

@TypedShellRoute<ShellRoute>(
  routes: [
    TypedGoRoute<HomeRoute>(
      path: '/',
    ),
    TypedGoRoute<SettingsRoute>(
      path: '/settings',
    ),
  ],
)
class ShellRoute extends ShellRouteData {
  const ShellRoute();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    Widget navigator,
  ) {
    return ShellScreen(
      child: navigator,
    );
  }
}

class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(
    BuildContext context,
    GoRouterState state,
  ) {
    return const HomeScreen();
  }
}

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();

  @override
  Widget build(
    BuildContext context,
    GoRouterState state,
  ) {
    return const SettingsScreen();
  }
}
