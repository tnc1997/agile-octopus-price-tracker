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
            final messenger = ScaffoldMessenger.of(context);
            final preferences = context.read<SharedPreferencesAsync>();
            final router = GoRouter.of(context);

            try {
              await preferences.setString(
                'import_product_code',
                importProductCodeNotifier.value!,
              );
            } catch (e) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Failed to set the import product code.'),
                ),
              );

              return;
            }

            final PaginatedGridSupplyPointList list;

            try {
              list = await client.industry.listIndustryGridSupplyPoints(
                page: 1,
                postcode: postcodeController.value.text,
              );
            } catch (e) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Failed to list the grid supply points.'),
                ),
              );

              return;
            }

            final String groupId;

            try {
              groupId = list.results!.single.groupId!;
            } catch (e) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Failed to get the group identifier.'),
                ),
              );

              return;
            }

            try {
              await preferences.setString(
                'grid_supply_point_group_id',
                groupId,
              );
            } catch (e) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Failed to set the group identifier.'),
                ),
              );

              return;
            }

            final Product product;

            try {
              product = await client.products.retrieveAProduct(
                importProductCodeNotifier.value!,
                tariffsActiveAt: DateTime.now().toUtc(),
              );
            } catch (e) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Failed to retrieve the product.'),
                ),
              );

              return;
            }

            final String importTariffCode;

            try {
              importTariffCode = product
                  .singleRegisterElectricityTariffs![groupId]![
                      PaymentMethods.directDebitMonthly]!
                  .code!;
            } catch (e) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Failed to get the import tariff code.'),
                ),
              );

              return;
            }

            try {
              await preferences.setString(
                'import_tariff_code',
                importTariffCode,
              );
            } catch (e) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Failed to set the import tariff code.'),
                ),
              );

              return;
            }

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
