import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'shell_route.dart';

class ShellBottomNavigationBar extends StatelessWidget {
  const ShellBottomNavigationBar({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            const HomeRoute().go(context);
          case 1:
            const HistoryRoute().go(context);
          case 2:
            const SettingsRoute().go(context);
          default:
            const HomeRoute().go(context);
        }
      },
      currentIndex: switch (GoRouterState.of(context).uri.path) {
        '/' => 0,
        '/history' => 1,
        '/settings' => 2,
        _ => 0,
      },
    );
  }
}
