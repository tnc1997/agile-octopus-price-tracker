import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutButton extends StatelessWidget {
  const AboutButton({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return FilledButton(
      onPressed: () {
        showAboutDialog(
          context: context,
          applicationName: 'Price Tracker for Agile Octopus',
          applicationVersion: '0.3.0',
          applicationLegalese: 'Copyright (c) 2025 Thomas Clark',
          children: [
            const SizedBox(
              height: 16.0,
            ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Contains information from ',
                  ),
                  TextSpan(
                    text: 'OpenStreetMap',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        final url = Uri.https(
                          'openstreetmap.org',
                          '/copyright',
                        );

                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                  ),
                  const TextSpan(
                    text: ', which is made available here under the ',
                  ),
                  TextSpan(
                    text: 'Open Database License (ODbL)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        final url = Uri.https(
                          'opendatacommons.org',
                          '/licenses/odbl',
                        );

                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                  ),
                  const TextSpan(
                    text: '.',
                  ),
                ],
              ),
            ),
          ],
        );
      },
      child: const Text('About Price Tracker for Agile Octopus'),
    );
  }
}
