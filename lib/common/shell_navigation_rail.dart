import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../home/home_route.dart';
import '../settings/settings_route.dart';
import 'shell_route.dart';

class ShellNavigationRail extends StatelessWidget {
  const ShellNavigationRail({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return NavigationRail(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
      selectedIndex: switch (GoRouterState.of(context).uri.path) {
        '/' => 0,
        '/settings' => 1,
        _ => 0,
      },
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            const HomeRoute().go(context);
          case 1:
            const SettingsRoute().go(context);
          default:
            const HomeRoute().go(context);
        }
      },
      labelType: NavigationRailLabelType.all,
    );
  }
}
