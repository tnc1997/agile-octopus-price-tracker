import 'package:flutter/material.dart';

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
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Card(
              child: TariffForm(),
            ),
          ),
        ],
      ),
    );
  }
}
