import 'package:flutter/material.dart';

import '../common/constants.dart';

class ImportProductCodeFormField extends StatelessWidget {
  const ImportProductCodeFormField({
    super.key,
    this.enabled = true,
    this.error,
    required this.value,
    required this.onChanged,
  });

  /// Whether the value can be manually changed via the drop-down.
  ///
  /// Set to `false` by `_TariffFormState` when the "Auto-select latest
  /// tariff for my region" checkbox is on. In that case [value] may be a
  /// tariff fetched from the API that predates this widget's hard-coded
  /// items (that's the point of auto-selecting), so rather than force it
  /// through [DropdownButtonFormField] — which asserts its value matches
  /// exactly one item — it's shown as read-only text instead.
  final bool enabled;

  /// A widget to show in place of the usual helper text when auto-select
  /// couldn't resolve a tariff, e.g.
  /// `Text('Failed to find the latest available tariff.')`. Only meaningful
  /// while [enabled] is `false`; a disabled field with no [value] and no
  /// [error] reads as still resolving, rather than having failed.
  final Widget? error;

  final String? value;

  final void Function(String?) onChanged;

  @override
  Widget build(
    BuildContext context,
  ) {
    if (enabled) {
      return DropdownButtonFormField<String>(
        key: ValueKey(value),
        items: [
          for (final entry in importProductCodeLabels.entries)
            DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        initialValue: value,
        onChanged: onChanged,
        decoration: const InputDecoration(
          label: Text('Tariff'),
          helper: Text('The version applied to your account'),
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select your tariff.';
          }

          return null;
        },
      );
    }

    return TextFormField(
      key: ValueKey(value),
      initialValue: importProductCodeLabels[value] ?? value,
      enabled: false,
      decoration: InputDecoration(
        label: const Text('Tariff'),
        helper: Text('The version applied to your account'),
        error: error,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
