import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'welcome_screen.dart';

part 'welcome_route.g.dart';

@TypedGoRoute<WelcomeRoute>(
  path: '/welcome',
)
class WelcomeRoute extends GoRouteData {
  const WelcomeRoute();

  @override
  Widget build(
    BuildContext context,
    GoRouterState state,
  ) {
    return const WelcomeScreen();
  }
}
