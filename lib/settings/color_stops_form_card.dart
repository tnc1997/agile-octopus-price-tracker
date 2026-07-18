import 'package:flutter/material.dart';

import 'color_stops_form.dart';
import 'settings_card_header.dart';

class ColorStopsFormCard extends StatelessWidget {
  const ColorStopsFormCard({
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
              subtitle: 'The colour thresholds used for the charts and cards',
              title: 'Price colour thresholds',
            ),
            ColorStopsForm(),
          ],
        ),
      ),
    );
  }
}
