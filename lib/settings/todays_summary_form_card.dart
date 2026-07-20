import 'package:flutter/material.dart';

import 'settings_card_header.dart';
import 'todays_summary_form.dart';

class TodaysSummaryFormCard extends StatelessWidget {
  const TodaysSummaryFormCard({
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
              subtitle: 'The settings for the today\'s summary card',
              title: 'Today\'s summary',
            ),
            TodaysSummaryForm(),
          ],
        ),
      ),
    );
  }
}
