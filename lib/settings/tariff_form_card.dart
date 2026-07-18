import 'package:flutter/material.dart';

import 'settings_card_header.dart';
import 'tariff_form.dart';

class TariffFormCard extends StatelessWidget {
  const TariffFormCard({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16.0,
          children: [
            SettingsCardHeader(
              subtitle: 'The region and tariff used to get prices',
              title: 'Region and tariff',
            ),
            TariffForm(),
          ],
        ),
      ),
    );
  }
}
