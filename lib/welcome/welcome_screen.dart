import 'package:flutter/material.dart';

import '../settings/tariff_form.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: TariffForm(),
        ),
      ),
    );
  }
}
