import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_route.dart';
import '../main.dart';

class ContinueButton extends StatelessWidget {
  const ContinueButton({
    super.key,
    required this.formKey,
    required this.importProductCodeNotifier,
    required this.postcodeController,
  });

  final GlobalKey<FormState> formKey;

  final ValueNotifier<String?> importProductCodeNotifier;

  final TextEditingController postcodeController;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        if (formKey.currentState case final state?) {
          if (state.validate()) {
            final client = context.read<OctopusEnergyApiClient>();
            final preferences = context.read<SharedPreferencesAsync>();
            final router = GoRouter.of(context);

            final list = await client.industry.listIndustryGridSupplyPoints(
              page: 1,
              postcode: postcodeController.value.text,
            );

            await preferences.setString(
              'import_product_code',
              importProductCodeNotifier.value!,
            );

            await preferences.setString(
              'region_code',
              list.results.single.groupId,
            );

            router.go(
              const HomeRoute().location,
            );
          }
        }
      },
      child: const Text('Continue'),
    );
  }
}
