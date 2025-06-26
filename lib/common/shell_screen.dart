import 'package:flutter/material.dart';

import 'shell_bottom_navigation_bar.dart';
import 'shell_navigation_rail.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 992) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  const ShellNavigationRail(),
                  const VerticalDivider(),
                  Expanded(
                    child: child,
                  ),
                ],
              ),
            ),
          );
        } else {
          return Scaffold(
            body: SafeArea(
              child: child,
            ),
            bottomNavigationBar: const ShellBottomNavigationBar(),
          );
        }
      },
    );
  }
}
