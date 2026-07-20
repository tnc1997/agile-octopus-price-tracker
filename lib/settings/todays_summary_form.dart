import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/constants.dart';
import 'hours_below_threshold_form_field.dart';
import 'tariff_comparison_rate_form_field.dart';

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
  /// Starts out at [_savedHoursBelowThreshold]'s default, overwritten with the
  /// persisted value once [initState]'s preferences read completes (if a
  /// value has actually been persisted), and edited directly by
  /// [HoursBelowThresholdFormField] as the user types. Read (and parsed)
  /// by [_SaveButton] both to detect whether this section is dirty and, on
  /// save, to persist the new threshold. Disposed in [dispose].
  final _hoursBelowThresholdController = TextEditingController(
    text: defaultHoursBelowThreshold.toStringAsFixed(2),
  );

  /// The controller holding the tariff comparison rate's current, unparsed
  /// text.
  ///
  /// Starts out at [_savedTariffComparisonRate]'s default, overwritten with
  /// the persisted value once [initState]'s preferences read completes (if a
  /// value has actually been persisted), and edited directly by
  /// [TariffComparisonRateFormField] as the user types. Read (and parsed) by
  /// [_SaveButton] both to detect whether this section is dirty and, on
  /// save, to persist the new rate. Disposed in [dispose].
  final _tariffComparisonRateController = TextEditingController(
    text: defaultTariffComparisonRate.toStringAsFixed(2),
  );

  /// The last-persisted hours below threshold, i.e. the value currently
  /// written to the `hours_below_threshold` preference.
  ///
  /// Defaults to [defaultHoursBelowThreshold] — the same default
  /// [getHoursBelowThreshold] in `lib/common/functions.dart` falls back to
  /// when nothing has been persisted yet — and is overwritten with the
  /// persisted value once [initState]'s preferences read completes.
  /// [_SaveButton] parses the controller's text and compares the result
  /// against this field to decide whether the section is dirty, then
  /// advances this field to the newly parsed value once a save succeeds (via
  /// `onPersisted`).
  double _savedHoursBelowThreshold = defaultHoursBelowThreshold;

  /// The last-persisted tariff comparison rate, i.e. the value currently
  /// written to the `tariff_comparison_rate` preference.
  ///
  /// Defaults to [defaultTariffComparisonRate] — the same default
  /// [getTariffComparisonRate] in `lib/common/functions.dart` falls back to
  /// when nothing has been persisted yet — and is overwritten with the
  /// persisted value once [initState]'s preferences read completes.
  /// [_SaveButton] parses the controller's text and compares the result
  /// against this field to decide whether the section is dirty, then
  /// advances this field to the newly parsed value once a save succeeds (via
  /// `onPersisted`).
  double _savedTariffComparisonRate = defaultTariffComparisonRate;

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
          TariffComparisonRateFormField(
            controller: _tariffComparisonRateController,
          ),
          _SaveButton(
            formKey: _formKey,
            hoursBelowThresholdController: _hoursBelowThresholdController,
            tariffComparisonRateController: _tariffComparisonRateController,
            savedHoursBelowThreshold: _savedHoursBelowThreshold,
            savedTariffComparisonRate: _savedTariffComparisonRate,
            onPersisted: () {
              setState(() {
                _savedHoursBelowThreshold = double.parse(
                  _hoursBelowThresholdController.text,
                );
                _savedTariffComparisonRate = double.parse(
                  _tariffComparisonRateController.text,
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
    _tariffComparisonRateController.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final preferences = context.read<SharedPreferencesAsync>();

    preferences.getDouble('hours_below_threshold').then((value) {
      if (value != null) {
        setState(() {
          _hoursBelowThresholdController.text = value.toStringAsFixed(2);
          _savedHoursBelowThreshold = value;
        });
      }
    });

    preferences.getDouble('tariff_comparison_rate').then((value) {
      if (value != null) {
        setState(() {
          _tariffComparisonRateController.text = value.toStringAsFixed(2);
          _savedTariffComparisonRate = value;
        });
      }
    });
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.formKey,
    required this.hoursBelowThresholdController,
    required this.tariffComparisonRateController,
    required this.onPersisted,
    required this.savedHoursBelowThreshold,
    required this.savedTariffComparisonRate,
  });

  final GlobalKey<FormState> formKey;

  final TextEditingController hoursBelowThresholdController;

  final TextEditingController tariffComparisonRateController;

  /// Invoked once the data has been successfully persisted, so the parent
  /// can update its "last-saved" values and re-disable the Save button.
  final VoidCallback onPersisted;

  /// The last-saved hours below threshold, i.e. the value currently
  /// persisted to preferences.
  ///
  /// Defaults to [defaultHoursBelowThreshold] until
  /// [_TodaysSummaryFormState.initState]'s preferences read completes with an
  /// actually-persisted value. Compared against
  /// [hoursBelowThresholdController]'s parsed value to decide whether this
  /// form has unsaved changes.
  final double savedHoursBelowThreshold;

  /// The last-saved tariff comparison rate, i.e. the value currently
  /// persisted to preferences.
  ///
  /// Defaults to [defaultTariffComparisonRate] until
  /// [_TodaysSummaryFormState.initState]'s preferences read completes with an
  /// actually-persisted value. Compared against
  /// [tariffComparisonRateController]'s parsed value to decide whether this
  /// form has unsaved changes.
  final double savedTariffComparisonRate;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        hoursBelowThresholdController,
        tariffComparisonRateController,
      ]),
      builder: (context, child) {
        final hoursBelowThreshold = double.tryParse(
          hoursBelowThresholdController.text,
        );

        final tariffComparisonRate = double.tryParse(
          tariffComparisonRateController.text,
        );

        return FilledButton(
          onPressed: hoursBelowThreshold != savedHoursBelowThreshold ||
                  tariffComparisonRate != savedTariffComparisonRate
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

    try {
      await preferences.setDouble(
        'tariff_comparison_rate',
        double.parse(tariffComparisonRateController.text),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to set the tariff comparison rate.'),
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
