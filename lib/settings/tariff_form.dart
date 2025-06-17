import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/shell_route.dart';
import '../home/home_route.dart';
import '../main.dart';
import 'grid_supply_point_group_id_form_field.dart';
import 'import_product_code_form_field.dart';

class TariffForm extends StatefulWidget {
  const TariffForm({
    super.key,
  });

  @override
  State<TariffForm> createState() {
    return _TariffFormState();
  }
}

class _TariffFormState extends State<TariffForm> {
  final _formKey = GlobalKey<FormState>();
  final _gridSupplyPointGroupIdNotifier = ValueNotifier<String?>(null);
  final _importProductCodeNotifier = ValueNotifier<String?>(null);

  @override
  Widget build(
    BuildContext context,
  ) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16.0,
          children: [
            GridSupplyPointGroupIdFormField(
              notifier: _gridSupplyPointGroupIdNotifier,
            ),
            ImportProductCodeFormField(
              notifier: _importProductCodeNotifier,
            ),
            _SaveButton(
              formKey: _formKey,
              gridSupplyPointGroupIdNotifier: _gridSupplyPointGroupIdNotifier,
              importProductCodeNotifier: _importProductCodeNotifier,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gridSupplyPointGroupIdNotifier.dispose();
    _importProductCodeNotifier.dispose();

    super.dispose();
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.formKey,
    required this.gridSupplyPointGroupIdNotifier,
    required this.importProductCodeNotifier,
  });

  final GlobalKey<FormState> formKey;

  final ValueNotifier<String?> gridSupplyPointGroupIdNotifier;

  final ValueNotifier<String?> importProductCodeNotifier;

  @override
  Widget build(
    BuildContext context,
  ) {
    return FilledButton(
      onPressed: () async {
        if (formKey.currentState case final formState?) {
          if (formState.validate()) {
            final client = context.read<OctopusEnergyApiClient>();
            final messenger = ScaffoldMessenger.of(context);
            final preferences = context.read<SharedPreferencesAsync>();
            final router = GoRouter.of(context);
            final routerState = GoRouterState.of(context);

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

            try {
              await preferences.setString(
                'grid_supply_point_group_id',
                gridSupplyPointGroupIdNotifier.value!,
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
                  .singleRegisterElectricityTariffs![
                      gridSupplyPointGroupIdNotifier
                          .value!]![PaymentMethods.directDebitMonthly]!
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

            if (routerState.uri.path == '/welcome') {
              router.go(
                const HomeRoute().location,
              );
            }
          }
        }
      },
      child: const Text('Save'),
    );
  }
}
