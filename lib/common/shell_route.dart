import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../home/home_route.dart';
import '../settings/settings_route.dart';
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
