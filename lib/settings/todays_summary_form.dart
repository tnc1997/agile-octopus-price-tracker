import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hours_below_threshold_form_field.dart';

class TodaysSummaryForm extends StatefulWidget {
  const TodaysSummaryForm({
    super.key,
  });

  @override
  State<TodaysSummaryForm> createState() {
    return _TodaysSummaryFormState();
  }
}

class _TodaysSummaryFormState extends State<TodaysSummaryForm> {
  final _formKey = GlobalKey<FormState>();

  /// The controller holding the hours below threshold's current, unparsed
  /// text.
  ///
  /// Starts out empty, overwritten with the persisted value once
  /// [initState]'s preferences read completes, and edited directly by
  /// [HoursBelowThresholdFormField] as the user types. Read (and parsed)
  /// by [_SaveButton] both to detect whether this section is dirty and, on
  /// save, to persist the new threshold. Disposed in [dispose].
  final _hoursBelowThresholdController = TextEditingController();

  /// The last-persisted hours below threshold, i.e. the value currently
  /// written to the `hours_below_threshold` preference.
  ///
  /// `null` until [initState]'s preferences read completes. [_SaveButton]
  /// parses the controller's text and compares the result against this field
  /// to decide whether the section is dirty, then advances this field to the
  /// newly parsed value once a save succeeds (via `onPersisted`).
  double? _savedHoursBelowThreshold;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16.0,
        children: [
          HoursBelowThresholdFormField(
            controller: _hoursBelowThresholdController,
          ),
          _SaveButton(
            formKey: _formKey,
            hoursBelowThresholdController: _hoursBelowThresholdController,
            savedHoursBelowThreshold: _savedHoursBelowThreshold,
            onPersisted: () {
              setState(() {
                _savedHoursBelowThreshold = double.tryParse(
                  _hoursBelowThresholdController.text,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hoursBelowThresholdController.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final preferences = context.read<SharedPreferencesAsync>();

    preferences.getDouble('hours_below_threshold').then((value) {
      setState(() {
        if (value != null) {
          _hoursBelowThresholdController.text = value.toStringAsFixed(2);
          _savedHoursBelowThreshold = value;
        }
      });
    });
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.formKey,
    required this.hoursBelowThresholdController,
    required this.onPersisted,
    required this.savedHoursBelowThreshold,
  });

  final GlobalKey<FormState> formKey;

  final TextEditingController hoursBelowThresholdController;

  /// Invoked once the data has been successfully persisted, so the parent
  /// can update its "last-saved" value and re-disable the Save button.
  final VoidCallback onPersisted;

  /// The last-saved hours below threshold, i.e. the value currently
  /// persisted to preferences.
  ///
  /// `null` until [_TodaysSummaryFormState.initState]'s preferences
  /// read completes. Compared against
  /// [hoursBelowThresholdController]'s parsed value to decide whether this
  /// form has unsaved changes.
  final double? savedHoursBelowThreshold;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListenableBuilder(
      listenable: hoursBelowThresholdController,
      builder: (context, child) {
        final hoursBelowThreshold = double.tryParse(
          hoursBelowThresholdController.text,
        );

        return FilledButton(
          onPressed: hoursBelowThreshold != savedHoursBelowThreshold
              ? () => _save(context)
              : null,
          child: const Text('Save'),
        );
      },
    );
  }

  Future<void> _save(
    BuildContext context,
  ) async {
    if (formKey.currentState?.validate() != true) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final preferences = context.read<SharedPreferencesAsync>();

    try {
      await preferences.setDouble(
        'hours_below_threshold',
        double.parse(hoursBelowThresholdController.text),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to set the hours below threshold.'),
        ),
      );

      return;
    }

    onPersisted();

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Today\'s summary saved.'),
      ),
    );
  }
}
