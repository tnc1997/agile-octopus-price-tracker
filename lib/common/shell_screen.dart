import 'package:flutter/material.dart';

import 'shell_bottom_navigation_bar.dart';

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
    return Scaffold(
      body: SafeArea(
        child: child,
      ),
      bottomNavigationBar: const ShellBottomNavigationBar(),
    );
  }
}
