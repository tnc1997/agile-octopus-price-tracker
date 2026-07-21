import 'package:flutter/material.dart';

/// A checkbox that lets the user opt in to having the app automatically keep
/// [ImportProductCodeFormField] on the latest available Agile Octopus
/// tariff, instead of pinning it to a manually-chosen version.
///
/// This does not own or persist the value it edits, nor does it fetch the
/// latest tariff itself — it merely reflects the value passed in by the
/// parent `_TariffFormState`, which is responsible for deriving it from
/// (and, on save, persisting it as) whether `import_product_code` is unset,
/// and for refreshing the auto-selected tariff whenever this is enabled.
class AutoSelectLatestImportProductCodeFormField extends StatelessWidget {
  const AutoSelectLatestImportProductCodeFormField({
    super.key,
    required this.onChanged,
    required this.value,
  });

  final void Function(bool) onChanged;

  final bool value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return CheckboxListTile(
      value: value,
      onChanged: (checked) => onChanged(checked ?? false),
      title: const Text(
        'Auto-select the latest tariff for my region',
      ),
    );
  }
}
