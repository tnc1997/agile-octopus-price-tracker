import 'package:flutter/material.dart';

import 'about_button.dart';
import 'tariff_form.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return const SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16.0,
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: TariffForm(),
            ),
            AboutButton(),
          ],
        ),
      ),
    );
  }
}
