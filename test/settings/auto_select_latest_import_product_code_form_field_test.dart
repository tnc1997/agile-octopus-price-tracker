import 'package:agile_octopus_price_tracker/settings/auto_select_latest_import_product_code_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'AutoSelectLatestImportProductCodeFormField',
    () {
      testWidgets(
        'invokes onChanged with false when tapped while checked',
        (tester) async {
          bool? changedTo;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AutoSelectLatestImportProductCodeFormField(
                  onChanged: (value) {
                    changedTo = value;
                  },
                  value: true,
                ),
              ),
            ),
          );

          await tester.tap(
            find.byType(CheckboxListTile),
          );

          await tester.pump();

          expect(
            changedTo,
            isFalse,
          );
        },
      );

      testWidgets(
        'invokes onChanged with true when tapped while unchecked',
        (tester) async {
          bool? changedTo;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AutoSelectLatestImportProductCodeFormField(
                  onChanged: (value) {
                    changedTo = value;
                  },
                  value: false,
                ),
              ),
            ),
          );

          await tester.tap(
            find.byType(CheckboxListTile),
          );

          await tester.pump();

          expect(
            changedTo,
            isTrue,
          );
        },
      );

      testWidgets(
        'reflects the given value in the checkbox state',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AutoSelectLatestImportProductCodeFormField(
                  onChanged: (_) {},
                  value: true,
                ),
              ),
            ),
          );

          final checkbox = tester.widget<CheckboxListTile>(
            find.byType(CheckboxListTile),
          );

          expect(
            checkbox.value,
            isTrue,
          );
        },
      );

      testWidgets(
        'renders a checkbox titled "Auto-select the latest tariff for my region"',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AutoSelectLatestImportProductCodeFormField(
                  onChanged: (_) {},
                  value: false,
                ),
              ),
            ),
          );

          expect(
            find.widgetWithText(
              CheckboxListTile,
              'Auto-select the latest tariff for my region',
            ),
            findsOneWidget,
          );
        },
      );
    },
  );
}
