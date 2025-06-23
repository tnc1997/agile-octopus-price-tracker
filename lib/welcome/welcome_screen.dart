import 'package:flutter/material.dart';

import '../settings/tariff_form_card.dart';
import 'welcome_card.dart';

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
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16.0,
              children: [
                WelcomeCard(),
                TariffFormCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
