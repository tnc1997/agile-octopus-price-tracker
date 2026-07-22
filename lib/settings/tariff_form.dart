import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/constants.dart';
import '../common/functions.dart';
import '../common/shell_route.dart';
import '../main.dart';
import 'auto_select_latest_import_product_code_form_field.dart';
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

  /// Whether the tariff should be kept up to date automatically, which may
  /// not yet match what's persisted.
  ///
  /// There's no dedicated preference for this — it's just whether
  /// `import_product_code` is unset, which is what
  /// [getImportProductCodeAndImportTariffCode] also keys off. Defaults to
  /// `true` so a brand-new install (nothing saved yet, before [initState]'s
  /// preferences read completes) starts with auto-select on; that read then
  /// sets this to [_importProductCode] being `null`, which flips it to
  /// `false` for an existing install with a manually-chosen tariff — neither
  /// case needs its own migration or default handling. Toggling
  /// [AutoSelectLatestImportProductCodeFormField] updates this via
  /// `setState` and, when turning it on, triggers
  /// [_refreshAutoSelectedImportProductCode] so [_importProductCode] reflects
  /// the current auto-selection rather than sitting blank.
  var _autoSelectLatestImportProductCode = true;

  /// A widget to show instead of [ImportProductCodeFormField]'s usual
  /// helper text when [_refreshAutoSelectedImportProductCode] fails to
  /// resolve a tariff.
  ///
  /// Distinguishes "auto-select couldn't find a tariff" from "still
  /// resolving" or "resolved successfully" — both of which leave this
  /// `null` — so the field never presents a plain blank in place of a
  /// genuine failure. Cleared whenever a refresh starts or succeeds, and
  /// whenever auto-select is switched off (the drop-down goes back to
  /// validating itself in that case).
  Widget? _autoSelectLatestImportProductCodeError;

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

  /// The import product code currently shown in [ImportProductCodeFormField],
  /// which may not yet be persisted.
  ///
  /// While [_autoSelectLatestImportProductCode] is on, this is whatever
  /// [_refreshAutoSelectedImportProductCode] most recently resolved (or
  /// `null` if it hasn't resolved one yet — see
  /// [_autoSelectLatestImportProductCodeError] for why that's not itself an error
  /// state) — populated so the field can show the user which tariff is
  /// actually in effect while disabled, rather than presenting a blank
  /// field that gives no visibility into what auto-select chose. While off,
  /// this is the user's manual pick, populated via
  /// [ImportProductCodeFormField]'s `onChanged` callback, which is only
  /// reachable while that field is enabled.
  ///
  /// See [_gridSupplyPointGroupId] for the general "may not yet be
  /// persisted" mechanism, paired with [_savedImportProductCode] — but note
  /// that pairing only reflects *persisted* state; while auto-select is on,
  /// this holds a resolved-for-display value even though nothing is written
  /// to the `import_product_code` preference (see
  /// [_savedImportProductCode]'s doc for how [_SaveButton] accounts for
  /// that).
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
  /// written to the `import_product_code` preference, or `null` if
  /// auto-select is (persisted as) on.
  ///
  /// See [_savedGridSupplyPointGroupId] for the general mechanism, but note
  /// [_importProductCode] itself isn't compared against this directly:
  /// while auto-select is on, [_importProductCode] holds whatever tariff is
  /// currently resolved for *display*, which drifts over time as newer
  /// tariffs are published — that drift is expected and isn't itself an
  /// unsaved change. [_SaveButton] instead compares
  /// [_autoSelectLatestImportProductCode] against
  /// `savedImportProductCode == null`, and only compares
  /// [_importProductCode] itself when auto-select is off.
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
            enabled: !_autoSelectLatestImportProductCode,
            error: _autoSelectLatestImportProductCodeError,
            value: _importProductCode,
            onChanged: (importProductCode) {
              setState(() {
                _importProductCode = importProductCode;
              });
            },
          ),
          AutoSelectLatestImportProductCodeFormField(
            value: _autoSelectLatestImportProductCode,
            onChanged: (autoSelectLatestImportProductCode) {
              setState(() {
                _autoSelectLatestImportProductCode =
                    autoSelectLatestImportProductCode;

                _autoSelectLatestImportProductCodeError = null;

                if (autoSelectLatestImportProductCode ||
                    !importProductCodeLabels.containsKey(_importProductCode)) {
                  _importProductCode = null;
                }
              });

              if (autoSelectLatestImportProductCode) {
                _refreshAutoSelectedImportProductCode();
              }
            },
          ),
          _SaveButton(
            formKey: _formKey,
            autoSelectLatestImportProductCode:
                _autoSelectLatestImportProductCode,
            gridSupplyPointGroupId: _gridSupplyPointGroupId,
            importProductCode: _importProductCode,
            savedGridSupplyPointGroupId: _savedGridSupplyPointGroupId,
            savedImportProductCode: _savedImportProductCode,
            onPersisted: () {
              setState(() {
                _savedGridSupplyPointGroupId = _gridSupplyPointGroupId;
                _savedImportProductCode = _autoSelectLatestImportProductCode
                    ? null
                    : _importProductCode;
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

    getGridSupplyPointGroupId(preferences).then((value) {
      setState(() {
        _gridSupplyPointGroupId = value;
        _savedGridSupplyPointGroupId = value;
      });
    });

    getImportProductCode(preferences).then((value) {
      setState(() {
        _autoSelectLatestImportProductCode = value == null;
        _importProductCode = value;
        _savedImportProductCode = value;
      });

      if (value == null) {
        _refreshAutoSelectedImportProductCode();
      }
    });
  }

  /// Resolves the latest available Agile Octopus import product code and
  /// updates [_importProductCode] (or [_autoSelectLatestImportProductCodeError] on
  /// failure) to match.
  ///
  /// Called whenever auto-select is (or becomes) enabled — from [initState]
  /// if it's already persisted that way, and from the checkbox's `onChanged`
  /// if the user just turned it on — so the drop-down always shows which
  /// tariff is actually in effect while it's disabled, rather than a blank
  /// field with no indication of what auto-select actually chose.
  Future<void> _refreshAutoSelectedImportProductCode() async {
    final client = context.read<OctopusEnergyApiClient>();

    final Products? latest;

    try {
      latest = await findLatestAgileProduct(client);
    } catch (e) {
      setState(() {
        _autoSelectLatestImportProductCodeError = const Text(
          'Failed to get the latest available tariff.',
        );

        _importProductCode = null;
      });

      return;
    }

    if (latest == null) {
      setState(() {
        _autoSelectLatestImportProductCodeError = const Text(
          'Failed to find the latest available tariff.',
        );

        _importProductCode = null;
      });

      return;
    }

    setState(() {
      _autoSelectLatestImportProductCodeError = null;
      _importProductCode = latest!.code;
    });
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.autoSelectLatestImportProductCode,
    required this.formKey,
    required this.gridSupplyPointGroupId,
    required this.importProductCode,
    required this.onPersisted,
    required this.savedGridSupplyPointGroupId,
    required this.savedImportProductCode,
  });

  final bool autoSelectLatestImportProductCode;

  final GlobalKey<FormState> formKey;

  final String? gridSupplyPointGroupId;

  /// The import product code currently shown in
  /// [ImportProductCodeFormField] — resolved by auto-select or manually
  /// picked — or `null` if neither has happened yet (auto-select is still
  /// resolving, failed, or the user switched to manual with nothing chosen).
  /// See `_TariffFormState._importProductCode`.
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
  /// to preferences, or `null` if auto-select is (persisted as) on.
  ///
  /// Compared against [autoSelectLatestImportProductCode] (there's no
  /// dedicated preference for it — see
  /// `_TariffFormState._savedImportProductCode`) and, only while auto-select
  /// is off, against [importProductCode], to decide whether this form has
  /// unsaved changes.
  final String? savedImportProductCode;

  @override
  Widget build(
    BuildContext context,
  ) {
    return FilledButton(
      onPressed: importProductCode != null &&
              ((autoSelectLatestImportProductCode !=
                      (savedImportProductCode == null)) ||
                  (!autoSelectLatestImportProductCode &&
                      importProductCode != savedImportProductCode) ||
                  gridSupplyPointGroupId != savedGridSupplyPointGroupId)
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

    // Guaranteed non-null by `onPressed`'s guard above — auto-select always
    // has a resolved [importProductCode] by the time Save is reachable
    // (`_refreshAutoSelectedImportProductCode` populates it eagerly, not at
    // save time), and manual mode's own validator requires one too.
    final importProductCode = this.importProductCode!;

    final client = context.read<OctopusEnergyApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    final preferences = context.read<SharedPreferencesAsync>();
    final router = GoRouter.of(context);
    final routerState = GoRouterState.of(context);

    try {
      // Auto-select has no preference of its own: leaving
      // `import_product_code` unset *is* "on", so
      // [getImportProductCodeAndImportTariffCode] keeps resolving the
      // latest tariff fresh on every price fetch. Setting it *is* "off",
      // pinning the manually-chosen product for good.
      if (autoSelectLatestImportProductCode) {
        await preferences.remove('import_product_code');
      } else {
        await preferences.setString(
          'import_product_code',
          importProductCode,
        );
      }
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
        importProductCode,
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
      // Mirrors `import_product_code` above: cleared while auto-select is
      // on, rather than left holding a resolved value that
      // [getImportProductCodeAndImportTariffCode] wouldn't read back anyway
      // (it already re-fetches whenever *either* preference is unset).
      if (autoSelectLatestImportProductCode) {
        await preferences.remove('import_tariff_code');
      } else {
        await preferences.setString(
          'import_tariff_code',
          importTariffCode,
        );
      }
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
