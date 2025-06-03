import 'package:flutter/material.dart';

import 'continue_button.dart';
import 'import_product_code_form_field.dart';
import 'postcode_form_field.dart';

class WelcomeForm extends StatefulWidget {
  const WelcomeForm({
    super.key,
  });

  @override
  State<WelcomeForm> createState() {
    return _WelcomeFormState();
  }
}

class _WelcomeFormState extends State<WelcomeForm> {
  final _formKey = GlobalKey<FormState>();
  final _importProductCodeNotifier = ValueNotifier<String?>(null);
  final _postcodeController = TextEditingController();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: PostcodeFormField(
                controller: _postcodeController,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ImportProductCodeFormField(
                notifier: _importProductCodeNotifier,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ContinueButton(
                formKey: _formKey,
                postcodeController: _postcodeController,
                importProductCodeNotifier: _importProductCodeNotifier,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _importProductCodeNotifier.dispose();
    _postcodeController.dispose();

    super.dispose();
  }
}
