import 'package:flutter/material.dart';

class PostcodeFormField extends StatelessWidget {
  const PostcodeFormField({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(
    BuildContext context,
  ) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        label: Text('Postcode'),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your postcode.';
        }

        return null;
      },
    );
  }
}
