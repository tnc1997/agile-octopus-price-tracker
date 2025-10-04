import 'dart:convert';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
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
  var _lowColor = Color(0xff00ff00);
  var _mediumColor = Color(0xffffff00);
  var _highColor = Color(0xffff0000);

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16.0,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('10.00p/kWh'),
              ),
              ColorIndicator(
                onSelect: () async {
                  final lowColor = await showColorPickerDialog(
                    context,
                    _lowColor,
                    pickersEnabled: {
                      ColorPickerType.both: false,
                      ColorPickerType.primary: false,
                      ColorPickerType.accent: false,
                      ColorPickerType.bw: false,
                      ColorPickerType.custom: false,
                      ColorPickerType.wheel: true,
                    },
                  );

                  setState(() {
                    _lowColor = lowColor;
                  });
                },
                color: _lowColor,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text('20.00p/kWh'),
              ),
              ColorIndicator(
                onSelect: () async {
                  final mediumColor = await showColorPickerDialog(
                    context,
                    _mediumColor,
                    pickersEnabled: {
                      ColorPickerType.both: false,
                      ColorPickerType.primary: false,
                      ColorPickerType.accent: false,
                      ColorPickerType.bw: false,
                      ColorPickerType.custom: false,
                      ColorPickerType.wheel: true,
                    },
                  );

                  setState(() {
                    _mediumColor = mediumColor;
                  });
                },
                color: _mediumColor,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text('30.00p/kWh'),
              ),
              ColorIndicator(
                onSelect: () async {
                  final highColor = await showColorPickerDialog(
                    context,
                    _highColor,
                    pickersEnabled: {
                      ColorPickerType.both: false,
                      ColorPickerType.primary: false,
                      ColorPickerType.accent: false,
                      ColorPickerType.bw: false,
                      ColorPickerType.custom: false,
                      ColorPickerType.wheel: true,
                    },
                  );

                  setState(() {
                    _highColor = highColor;
                  });
                },
                color: _highColor,
              ),
            ],
          ),
          _SaveButton(
            lowColor: _lowColor,
            mediumColor: _mediumColor,
            highColor: _highColor,
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final preferences = context.read<SharedPreferencesAsync>();

    preferences.getString('color_stops').then((stops) {
      if (stops != null) {
        for (final stop in (json.decode(stops) as List<dynamic>)) {
          switch (stop['price']) {
            case 10.00:
              setState(() {
                _lowColor = Color(stop['color']);
              });
            case 20.00:
              setState(() {
                _mediumColor = Color(stop['color']);
              });
            case 30.00:
              setState(() {
                _highColor = Color(stop['color']);
              });
          }
        }
      }
    });
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.lowColor,
    required this.mediumColor,
    required this.highColor,
  });

  final Color lowColor;

  final Color mediumColor;

  final Color highColor;

  @override
  Widget build(
    BuildContext context,
  ) {
    return FilledButton(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final preferences = context.read<SharedPreferencesAsync>();

        try {
          await preferences.setString(
            'color_stops',
            json.encode([
              {
                'color': lowColor.toARGB32(),
                'price': 10.00,
              },
              {
                'color': mediumColor.toARGB32(),
                'price': 20.00,
              },
              {
                'color': highColor.toARGB32(),
                'price': 30.00,
              },
            ]),
          );
        } catch (e) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to set the color stops.'),
            ),
          );

          return;
        }
      },
      child: const Text('Save'),
    );
  }
}
