import 'dart:convert';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorStopsForm extends StatefulWidget {
  const ColorStopsForm({
    super.key,
  });

  @override
  State<ColorStopsForm> createState() {
    return _ColorStopsFormState();
  }
}

class _ColorStopsFormState extends State<ColorStopsForm> {
  final _formKey = GlobalKey<FormState>();

  var _negativeColor = Color(0xff00ffff);
  var _lowColor = Color(0xff00ff00);
  var _mediumColor = Color(0xffffff00);
  var _highColor = Color(0xffff0000);

  final _lowPriceController = TextEditingController(text: '10.00');
  final _mediumPriceController = TextEditingController(text: '20.00');
  final _highPriceController = TextEditingController(text: '30.00');

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
          Row(
            spacing: 16.0,
            children: [
              const Expanded(
                child: Text('< 0.00p/kWh'),
              ),
              _ColorStopColorColorIndicator(
                color: _negativeColor,
                onChanged: (color) {
                  setState(() {
                    _negativeColor = color;
                  });
                },
              ),
            ],
          ),
          Row(
            spacing: 16.0,
            children: [
              Expanded(
                child: _ColorStopPriceFormField(
                  controller: _lowPriceController,
                ),
              ),
              _ColorStopColorColorIndicator(
                color: _lowColor,
                onChanged: (color) {
                  setState(() {
                    _lowColor = color;
                  });
                },
              ),
            ],
          ),
          Row(
            spacing: 16.0,
            children: [
              Expanded(
                child: _ColorStopPriceFormField(
                  controller: _mediumPriceController,
                ),
              ),
              _ColorStopColorColorIndicator(
                color: _mediumColor,
                onChanged: (color) {
                  setState(() {
                    _mediumColor = color;
                  });
                },
              ),
            ],
          ),
          Row(
            spacing: 16.0,
            children: [
              Expanded(
                child: _ColorStopPriceFormField(
                  controller: _highPriceController,
                ),
              ),
              _ColorStopColorColorIndicator(
                color: _highColor,
                onChanged: (color) {
                  setState(() {
                    _highColor = color;
                  });
                },
              ),
            ],
          ),
          _SaveButton(
            formKey: _formKey,
            negativeColor: _negativeColor,
            lowColor: _lowColor,
            lowPriceController: _lowPriceController,
            mediumColor: _mediumColor,
            mediumPriceController: _mediumPriceController,
            highColor: _highColor,
            highPriceController: _highPriceController,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _lowPriceController.dispose();
    _mediumPriceController.dispose();
    _highPriceController.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final preferences = context.read<SharedPreferencesAsync>();

    // `color_stops` is always saved (see _SaveButton) as an ordered list
    // of exactly 4 stops: negative, low, medium, high. The low/medium/high
    // prices are user-editable, so they can no longer be used to identify
    // which stop is which — we match by position in the ordered list
    // instead. Guard the length so a corrupted preference or a future
    // schema change (a different stop count) can't crash this list-pattern
    // match — we simply keep the defaults instead.
    preferences.getString('color_stops').then((stops) {
      if (stops == null) {
        return;
      }

      final decoded = json.decode(stops);

      if (decoded is! List<dynamic> || decoded.length != 4) {
        return;
      }

      final [negative, low, medium, high] = decoded;

      setState(() {
        _negativeColor = Color(negative['color']);

        _lowColor = Color(low['color']);
        _lowPriceController.text = low['price'].toStringAsFixed(2);

        _mediumColor = Color(medium['color']);
        _mediumPriceController.text = medium['price'].toStringAsFixed(2);

        _highColor = Color(high['color']);
        _highPriceController.text = high['price'].toStringAsFixed(2);
      });
    });
  }
}

/// A tappable color swatch representing a single color stop's current
/// color, which opens the color picker dialog and reports back whatever
/// color the user chooses.
///
/// This factors out the color-picking logic that used to be duplicated
/// four times in [_ColorStopsFormState.build] (once per stop: negative,
/// low, medium, high) — each occurrence differed only in which color was
/// currently selected and which `setState` callback should run when the
/// user picks a new one. Those two differences are now exactly the
/// [color] and [onChanged] parameters below, so all four stops share a
/// single implementation of the actual picker-dialog wiring.
///
/// This widget is intentionally "dumb": it does not know whether it is
/// showing the negative, low, medium, or high stop, and it does not own or
/// persist the selected color itself. It only displays [color] and, once
/// the user picks a new one from the dialog, invokes [onChanged] so that
/// the parent [_ColorStopsFormState] can update its own state (and,
/// eventually, [_SaveButton] can persist it).
class _ColorStopColorColorIndicator extends StatelessWidget {
  const _ColorStopColorColorIndicator({
    required this.color,
    required this.onChanged,
  });

  /// The color stop's currently selected color, shown as the swatch.
  ///
  /// Owned by [_ColorStopsFormState] — this widget only ever displays it,
  /// it never mutates it directly.
  final Color color;

  /// Invoked with the newly picked color once the user closes the color
  /// picker dialog having made a selection.
  ///
  /// The caller (one of the four call sites in
  /// [_ColorStopsFormState.build]) is expected to respond by calling
  /// `setState` to update the corresponding color field (e.g.
  /// `_negativeColor`, `_lowColor`, `_mediumColor`, or `_highColor`).
  final void Function(Color) onChanged;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ColorIndicator(
      onSelect: () async {
        final selected = await showColorPickerDialog(
          context,
          color,
          pickersEnabled: {
            ColorPickerType.both: false,
            ColorPickerType.primary: false,
            ColorPickerType.accent: false,
            ColorPickerType.bw: false,
            ColorPickerType.custom: false,
            ColorPickerType.wheel: true,
          },
        );

        onChanged(selected);
      },
      color: color,
    );
  }
}

/// A text field for editing the price threshold of a single color stop.
///
/// Renders with the same bordered [OutlineInputBorder] style used by the
/// other editable fields on the settings screen (e.g. Region, Tariff), with
/// a `p/kWh` suffix to make the unit explicit without the user having to
/// type it.
///
/// The negative-price stop is deliberately not edited through this widget:
/// it represents "any negative unit rate" as a category, not a threshold a
/// user would meaningfully want to move, and [calculatePriceColor] (in
/// `lib/common/functions.dart`) identifies it by scanning for whichever
/// stop has a price below zero — so this field only ever needs to accept
/// non-negative prices, and never needs a sign toggle.
///
/// This does not own or persist the value it edits — it merely reads from
/// and writes to the [controller] passed in by the parent
/// [_ColorStopsFormState], which is responsible for creating, disposing,
/// and ultimately saving that controller's text via [_SaveButton].
class _ColorStopPriceFormField extends StatelessWidget {
  const _ColorStopPriceFormField({
    required this.controller,
  });

  /// The controller that holds this field's current, unparsed price text.
  ///
  /// Owned by [_ColorStopsFormState] (one per color stop) so its value can
  /// survive rebuilds of this stateless widget and be read back by
  /// [_SaveButton] when the form is saved.
  final TextEditingController controller;

  @override
  Widget build(
    BuildContext context,
  ) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        label: Text('Price'),
        suffix: Text('p/kWh'),
        border: OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      validator: (value) {
        final parsed = value == null ? null : double.tryParse(value);

        if (parsed == null) {
          return 'Please enter a valid price.';
        }

        if (parsed < 0) {
          return 'Please enter a price above 0.00p/kWh.';
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

/// The button that validates and persists the color stops form.
///
/// On press, it validates every [_ColorStopPriceFormField] via [formKey], then
/// pairs each color with its corresponding, now-parsed price threshold and
/// writes the combined list to the `color_stops` shared preference as JSON.
/// That preference is read elsewhere (see [getColorStops] in
/// `lib/common/functions.dart`) to color the home screen chart and cards,
/// so this is the single point at which edits made in this form take
/// effect for the rest of the app.
///
/// This widget owns none of the state it saves — the colors and price
/// controllers are passed down from [_ColorStopsFormState] so that this
/// button only needs to read their current values at save time.
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.formKey,
    required this.negativeColor,
    required this.lowColor,
    required this.lowPriceController,
    required this.mediumColor,
    required this.mediumPriceController,
    required this.highColor,
    required this.highPriceController,
  });

  /// The key of the [Form] wrapping all four [_ColorStopPriceFormField]s.
  ///
  /// Used to run validation for every price field before saving, so that an
  /// invalid or empty price (see the field's `validator`) blocks the save
  /// and surfaces an inline error instead of being silently persisted.
  final GlobalKey<FormState> formKey;

  /// The currently selected color for the negative-price stop.
  ///
  /// Applies to unit rates below `0.00p/kWh`. Unlike the other three
  /// colors, this is saved alongside a fixed `-1.00` price rather than a
  /// user-editable one — see [_ColorStopPriceFormField]'s docs for why the
  /// negative threshold itself isn't editable.
  final Color negativeColor;

  /// The currently selected color for the "low" price stop.
  ///
  /// Paired with [lowPriceController]'s value when saving.
  final Color lowColor;

  /// The controller holding the "low" price stop's threshold text.
  final TextEditingController lowPriceController;

  /// The currently selected color for the "medium" price stop.
  ///
  /// Paired with [mediumPriceController]'s value when saving.
  final Color mediumColor;

  /// The controller holding the "medium" price stop's threshold text.
  final TextEditingController mediumPriceController;

  /// The currently selected color for the "high" price stop.
  ///
  /// Paired with [highPriceController]'s value when saving.
  final Color highColor;

  /// The controller holding the "high" price stop's threshold text.
  final TextEditingController highPriceController;

  @override
  Widget build(
    BuildContext context,
  ) {
    return FilledButton(
      onPressed: () async {
        if (formKey.currentState?.validate() != true) {
          return;
        }

        final messenger = ScaffoldMessenger.of(context);
        final preferences = context.read<SharedPreferencesAsync>();

        try {
          await preferences.setString(
            'color_stops',
            json.encode([
              {
                'color': negativeColor.toARGB32(),
                'price': -1.00,
              },
              {
                'color': lowColor.toARGB32(),
                'price': double.parse(lowPriceController.text),
              },
              {
                'color': mediumColor.toARGB32(),
                'price': double.parse(mediumPriceController.text),
              },
              {
                'color': highColor.toARGB32(),
                'price': double.parse(highPriceController.text),
              },
            ]),
          );
        } catch (e) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to set the price color thresholds.'),
            ),
          );

          return;
        }
      },
      child: const Text('Save'),
    );
  }
}
