import 'package:flutter/material.dart';

class ImportProductCodeFormField extends StatelessWidget {
  static const _items = [
    DropdownMenuItem<String>(
      value: 'AGILE-24-10-01',
      child: Text('Agile Octopus October 2024 v1'),
    ),
    DropdownMenuItem<String>(
      value: 'AGILE-24-04-03',
      child: Text('Agile Octopus April 2024 v1'),
    ),
    DropdownMenuItem<String>(
      value: 'AGILE-23-12-06',
      child: Text('Agile Octopus December 2023 v1'),
    ),
    DropdownMenuItem<String>(
      value: 'AGILE-FLEX-22-11-25',
      child: Text('Agile Octopus November 2022 v1'),
    ),
    DropdownMenuItem<String>(
      value: 'AGILE-22-08-31',
      child: Text('Agile Octopus August 2022 v1'),
    ),
    DropdownMenuItem<String>(
      value: 'AGILE-22-07-22',
      child: Text('Agile Octopus July 2022 v1'),
    ),
    DropdownMenuItem<String>(
      value: 'AGILE-18-02-21',
      child: Text('Agile Octopus February 2018'),
    ),
  ];

  const ImportProductCodeFormField({
    super.key,
    required this.notifier,
  });

  final ValueNotifier<String?> notifier;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, child) {
        return DropdownButtonFormField<String>(
          items: _items,
          value: value,
          onChanged: (value) {
            notifier.value = value;
          },
          decoration: const InputDecoration(
            label: Text('Tariff'),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your tariff.';
            }

            return null;
          },
        );
      },
    );
  }
}
