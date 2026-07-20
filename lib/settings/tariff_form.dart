import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/shell_route.dart';
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

  /// The currently selected grid supply point group identifier, which may
  /// not yet be persisted.
  ///
  /// Starts out `null` (and equal to [_savedGridSupplyPointGroupId]) until
  /// either [initState]'s preferences read completes or the user picks a
  /// region via [GridSupplyPointGroupIdFormField]'s `onChanged` callback,
  /// which updates this via `setState`. [_SaveButton] compares this against
  /// [_savedGridSupplyPointGroupId] to decide whether the section has
  /// unsaved changes, and reads it directly when persisting.
  String? _gridSupplyPointGroupId;

  /// The currently selected import product code, which may not yet be
  /// persisted.
  ///
  /// See [_gridSupplyPointGroupId] — this is the same mechanism, paired
  /// with [_savedImportProductCode] and populated via
  /// [ImportProductCodeFormField]'s `onChanged` callback instead.
  String? _importProductCode;

  /// The last-persisted grid supply point group identifier, i.e. the value
  /// currently written to the `grid_supply_point_group_id` preference.
  ///
  /// Kept in sync with what's actually on disk: starts out `null`,
  /// overwritten with the persisted value once [initState]'s preferences
  /// read completes, and advanced to [_gridSupplyPointGroupId]'s current
  /// value once [_SaveButton] reports a successful save via `onPersisted`.
  /// [_SaveButton] compares this against [_gridSupplyPointGroupId] to
  /// decide whether the section has unsaved changes.
  String? _savedGridSupplyPointGroupId;

  /// The last-persisted import product code, i.e. the value currently
  /// written to the `import_product_code` preference.
  ///
  /// See [_savedGridSupplyPointGroupId] — this is the same mechanism,
  /// paired with [_importProductCode] instead.
  String? _savedImportProductCode;

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
          GridSupplyPointGroupIdFormField(
            value: _gridSupplyPointGroupId,
            onChanged: (gridSupplyPointGroupId) {
              setState(() {
                _gridSupplyPointGroupId = gridSupplyPointGroupId;
              });
            },
          ),
          ImportProductCodeFormField(
            value: _importProductCode,
            onChanged: (importProductCode) {
              setState(() {
                _importProductCode = importProductCode;
              });
            },
          ),
          _SaveButton(
            formKey: _formKey,
            gridSupplyPointGroupId: _gridSupplyPointGroupId,
            importProductCode: _importProductCode,
            savedGridSupplyPointGroupId: _savedGridSupplyPointGroupId,
            savedImportProductCode: _savedImportProductCode,
            onPersisted: () {
              setState(() {
                _savedGridSupplyPointGroupId = _gridSupplyPointGroupId;
                _savedImportProductCode = _importProductCode;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final preferences = context.read<SharedPreferencesAsync>();

    preferences.getString('grid_supply_point_group_id').then((value) {
      setState(() {
        _gridSupplyPointGroupId = value;
        _savedGridSupplyPointGroupId = value;
      });
    });

    preferences.getString('import_product_code').then((value) {
      setState(() {
        _importProductCode = value;
        _savedImportProductCode = value;
      });
    });
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.formKey,
    required this.gridSupplyPointGroupId,
    required this.importProductCode,
    required this.onPersisted,
    required this.savedGridSupplyPointGroupId,
    required this.savedImportProductCode,
  });

  final GlobalKey<FormState> formKey;

  final String? gridSupplyPointGroupId;

  final String? importProductCode;

  /// Invoked once the data has been successfully persisted, so the parent
  /// can update its "last-saved" values and re-disable the Save button.
  final VoidCallback onPersisted;

  /// The last-saved grid supply point group identifier, i.e. the value
  /// currently persisted to preferences.
  ///
  /// Compared against [gridSupplyPointGroupId] to decide whether this
  /// form has unsaved changes.
  final String? savedGridSupplyPointGroupId;

  /// The last-saved import product code, i.e. the value currently persisted
  /// to preferences.
  ///
  /// Compared against [importProductCode] to decide whether this form
  /// has unsaved changes.
  final String? savedImportProductCode;

  @override
  Widget build(
    BuildContext context,
  ) {
    return FilledButton(
      onPressed: gridSupplyPointGroupId != savedGridSupplyPointGroupId ||
              importProductCode != savedImportProductCode
          ? () => _save(context)
          : null,
      child: const Text('Save'),
    );
  }

  Future<void> _save(
    BuildContext context,
  ) async {
    if (formKey.currentState?.validate() != true) {
      return;
    }

    final client = context.read<OctopusEnergyApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    final preferences = context.read<SharedPreferencesAsync>();
    final router = GoRouter.of(context);
    final routerState = GoRouterState.of(context);

    try {
      await preferences.setString(
        'import_product_code',
        importProductCode!,
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
        gridSupplyPointGroupId!,
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
      product = await client.products.retrieveProduct(
        importProductCode!,
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
          .singleRegisterElectricityTariffs![gridSupplyPointGroupId!]![
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

    onPersisted();

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Region and tariff saved.'),
      ),
    );

    if (routerState.uri.path == '/welcome') {
      router.go(
        const HomeRoute().location,
      );
    }
  }
}
