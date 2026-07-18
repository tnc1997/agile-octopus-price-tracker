import 'package:flutter/material.dart';

/// A bold section title, with an optional muted subtitle, shown at the top
/// of a settings card.
///
/// Each card on the settings screen (for example the region/tariff card and
/// the price color thresholds card) groups a set of related controls.
/// Before this widget existed, a user had to infer what a card was for
/// purely from its contents. Placing a [SettingsCardHeader] at the top of a
/// card gives it an explicit, scannable label instead.
///
/// The title is wrapped in [Semantics] with `header: true` so screen readers
/// announce it as a heading rather than as plain styled text, satisfying the
/// requirement that section titles be exposed to assistive technology as
/// headings and not just visually styled text.
class SettingsCardHeader extends StatelessWidget {
  const SettingsCardHeader({
    super.key,
    this.subtitle,
    required this.title,
  });

  /// An optional muted one-line summary of what this section controls.
  ///
  /// This is shown directly beneath [title] in a smaller, lower-emphasis
  /// style, so it reads as supplementary context rather than competing with
  /// the title for attention. Pass `null` (the default) to omit the
  /// subtitle entirely and show only the [title].
  final String? subtitle;

  /// The bold heading shown for this section.
  ///
  /// This should be a short (one to three word) label that names the
  /// section, written in sentence case to match the typography conventions
  /// used for headings elsewhere in the app (for example "Today's summary"
  /// on the home screen), for example "Region and tariff" or "Price color
  /// thresholds".
  final String title;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4.0,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (subtitle case final subtitle?)
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelMedium,
          ),
      ],
    );
  }
}
