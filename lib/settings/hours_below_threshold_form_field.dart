import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A text field for editing the hours below threshold, in p/kWh.
///
/// Renders with the same bordered [OutlineInputBorder] style used by the
/// other editable fields on the settings screen (e.g. Tariff comparison
/// rate), with a `p/kWh` suffix to make the unit explicit without the user
/// having to type it.
///
/// This does not own or persist the value it edits — it merely reads from
/// and writes to the [controller] passed in by the parent
/// `_TodaysSummaryFormState`, which is responsible for creating,
/// disposing, and ultimately saving that controller's text via its
/// `_SaveButton`.
class HoursBelowThresholdFormField extends StatelessWidget {
  const HoursBelowThresholdFormField({
    super.key,
    required this.controller,
  });

  /// The controller that holds this field's current, unparsed threshold
  /// text.
  ///
  /// Owned by `_TodaysSummaryFormState` so its value can survive
  /// rebuilds of this stateless widget and be read back by `_SaveButton`
  /// when the form is saved.
  final TextEditingController controller;

  @override
  Widget build(
    BuildContext context,
  ) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        label: Text('Hours below threshold'),
        helper: Text('The threshold used to count hours below'),
        suffix: Text('p/kWh'),
        border: OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(
        signed: false,
        decimal: true,
      ),
      validator: (value) {
        final parsed = value == null ? null : double.tryParse(value);

        if (parsed == null) {
          return 'Please enter a valid threshold.';
        }

        if (parsed < 0) {
          return 'Please enter a threshold above 0.00p/kWh.';
        }

        return null;
      },
      inputFormatters: [
        // FilteringTextInputFormatter.allow rejects the whole edit (not just
        // the offending character) whenever the new text doesn't match the
        // regular expression in one span — e.g. typing a second '.' after
        // '1.2' would wipe the field back to empty instead of just blocking
        // that keystroke. Falling back to the previous value keeps whatever
        // the user had already typed.
        TextInputFormatter.withFunction((oldValue, newValue) {
          if (RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)) {
            return newValue;
          }

          return oldValue;
        }),
      ],
    );
  }
}
