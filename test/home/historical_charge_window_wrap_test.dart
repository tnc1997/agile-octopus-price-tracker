import 'package:agile_octopus_price_tracker/home/historical_charge_window_card.dart';
import 'package:agile_octopus_price_tracker/home/historical_charge_window_wrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

void main() {
  group(
    'HistoricalChargeWindowWrap',
    () {
      testWidgets(
        'lays out cards using a narrower per-card width at a viewport width of 768 or below',
        (tester) async {
          // `materialApp`'s `surfaceSize` only overrides the `MediaQueryData`
          // seen by `MediaQuery.of(context)` — it doesn't resize the actual
          // test surface, so `LayoutBuilder`'s constraints (used to compute
          // `itemWidth`) would otherwise still reflect the binding's default
          // window size. Setting the view's physical size directly keeps both
          // in agreement.
          tester.view.physicalSize = const Size(700, 600);
          tester.view.devicePixelRatio = 1.0;

          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final now = DateTime.now().toUtc();

          final historicalCharges = [
            HistoricalCharge(
              validFrom: now,
              validTo: now.add(
                const Duration(
                  minutes: 30,
                ),
              ),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeWindowWrap(
                  colorStops: colorStops,
                  historicalCharges: historicalCharges,
                ),
              ),
            ),
          );

          // crossAxisCount is 2 at 700 wide: totalSpacing = 16 * 1 = 16,
          // availableWidth = 700 - 16 = 684, itemWidth = 684 / 2 = 342.
          final sizedBox = tester
              .widgetList<SizedBox>(
                find.ancestor(
                  of: find.byType(HistoricalChargeWindowCard),
                  matching: find.byType(SizedBox),
                ),
              )
              .first;

          expect(
            sizedBox.width,
            342.0,
          );
        },
      );

      testWidgets(
        'lays out cards using a narrower per-card width at a viewport width of exactly 768',
        (tester) async {
          // The crossAxisCount check is strictly `> 768`, so exactly 768
          // itself must still take the narrower, 2-column branch.
          tester.view.physicalSize = const Size(768, 600);
          tester.view.devicePixelRatio = 1.0;

          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final now = DateTime.now().toUtc();

          final historicalCharges = [
            HistoricalCharge(
              validFrom: now,
              validTo: now.add(
                const Duration(
                  minutes: 30,
                ),
              ),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeWindowWrap(
                  colorStops: colorStops,
                  historicalCharges: historicalCharges,
                ),
              ),
            ),
          );

          // crossAxisCount is 2 at 768 wide: totalSpacing = 16 * 1 = 16,
          // availableWidth = 768 - 16 = 752, itemWidth = 752 / 2 = 376.
          final sizedBox = tester
              .widgetList<SizedBox>(
                find.ancestor(
                  of: find.byType(HistoricalChargeWindowCard),
                  matching: find.byType(SizedBox),
                ),
              )
              .first;

          expect(
            sizedBox.width,
            376.0,
          );
        },
      );

      testWidgets(
        'lays out cards using a wider per-card width at a viewport width above 768',
        (tester) async {
          // See the equivalent comment in the narrower-viewport test above:
          // the view's physical size has to be set directly, alongside
          // `surfaceSize`, for `LayoutBuilder`'s constraints to actually
          // reflect it.
          tester.view.physicalSize = const Size(1024, 600);
          tester.view.devicePixelRatio = 1.0;

          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final now = DateTime.now().toUtc();

          final historicalCharges = [
            HistoricalCharge(
              validFrom: now,
              validTo: now.add(
                const Duration(
                  minutes: 30,
                ),
              ),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeWindowWrap(
                  colorStops: colorStops,
                  historicalCharges: historicalCharges,
                ),
              ),
            ),
          );

          // crossAxisCount is 4 above 768 wide: totalSpacing = 16 * 3 = 48,
          // availableWidth = 1024 - 48 = 976, itemWidth = 976 / 4 = 244.
          final sizedBox = tester
              .widgetList<SizedBox>(
                find.ancestor(
                  of: find.byType(HistoricalChargeWindowCard),
                  matching: find.byType(SizedBox),
                ),
              )
              .first;

          expect(
            sizedBox.width,
            244.0,
          );
        },
      );

      testWidgets(
        'renders Best, Current, Next and Avoid cards when the historicalCharges contain a cheapest window and a costlier remaining slot',
        (tester) async {
          // Fixed to a date safely in the past, so the charges below always
          // land before the widget's own "tomorrow midnight" cutoff,
          // regardless of when the test actually runs.
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final historicalCharges = [
            HistoricalCharge( // Current
              validFrom: DateTime.utc(1970, 1, 1, 1),
              validTo: DateTime.utc(1970, 1, 1, 1, 30),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
            HistoricalCharge( // Next
              validFrom: DateTime.utc(1970, 1, 1, 1, 30),
              validTo: DateTime.utc(1970, 1, 1, 2),
              valueExcVat: 25.0,
              valueIncVat: 25.0,
            ),
            HistoricalCharge( // Best window start
              validFrom: DateTime.utc(1970, 1, 1, 2),
              validTo: DateTime.utc(1970, 1, 1, 2, 30),
              valueExcVat: 5.0,
              valueIncVat: 5.0,
            ),
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 2, 30),
              validTo: DateTime.utc(1970, 1, 1, 3),
              valueExcVat: 5.0,
              valueIncVat: 5.0,
            ),
            HistoricalCharge(
              validFrom: DateTime.utc(1970, 1, 1, 3),
              validTo: DateTime.utc(1970, 1, 1, 3, 30),
              valueExcVat: 5.0,
              valueIncVat: 5.0,
            ),
            HistoricalCharge( // Best window end
              validFrom: DateTime.utc(1970, 1, 1, 3, 30),
              validTo: DateTime.utc(1970, 1, 1, 4),
              valueExcVat: 5.0,
              valueIncVat: 5.0,
            ),
            HistoricalCharge( // Avoid
              validFrom: DateTime.utc(1970, 1, 1, 4),
              validTo: DateTime.utc(1970, 1, 1, 4, 30),
              valueExcVat: 100.0,
              valueIncVat: 100.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeWindowWrap(
                  colorStops: colorStops,
                  historicalCharges: historicalCharges,
                ),
              ),
            ),
          );

          final cards = tester.widgetList<HistoricalChargeWindowCard>(
            find.byType(HistoricalChargeWindowCard),
          );

          expect(
            cards.length,
            4,
          );

          final byLabel = {
            for (final card in cards) card.label: card,
          };

          expect(
            byLabel.keys.toSet(),
            {'Current', 'Next', 'Best', 'Avoid'},
          );

          expect(
            byLabel['Current']!.value,
            20.0,
          );

          expect(
            byLabel['Next']!.value,
            25.0,
          );

          expect(
            byLabel['Best']!.value,
            5.0,
          );

          expect(
            byLabel['Best']!.prefix,
            'avg',
          );

          expect(
            byLabel['Avoid']!.value,
            100.0,
          );
        },
      );

      testWidgets(
        'renders Current, Next and Avoid cards but no Best card for exactly two charges',
        (tester) async {
          // Fixed the same way as the four-card test above, to avoid
          // flakiness near real local midnight.
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          // Only 1 hour of charges total, so `findCheapestWindow`'s 2-hour
          // window can never be found (no Best card), while `maxBy` still
          // finds a costliest slot among the two (Avoid still shows).
          final historicalCharges = [
            HistoricalCharge( // Current
              validFrom: DateTime.utc(1970, 1, 1, 1),
              validTo: DateTime.utc(1970, 1, 1, 1, 30),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
            HistoricalCharge( // Next, Avoid
              validFrom: DateTime.utc(1970, 1, 1, 1, 30),
              validTo: DateTime.utc(1970, 1, 1, 2),
              valueExcVat: 100.0,
              valueIncVat: 100.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeWindowWrap(
                  colorStops: colorStops,
                  historicalCharges: historicalCharges,
                ),
              ),
            ),
          );

          final cards = tester.widgetList<HistoricalChargeWindowCard>(
            find.byType(HistoricalChargeWindowCard),
          );

          final byLabel = {
            for (final card in cards) card.label: card,
          };

          expect(
            byLabel.keys.toSet(),
            {'Current', 'Next', 'Avoid'},
          );

          expect(
            byLabel['Avoid']!.value,
            100.0,
          );
        },
      );

      testWidgets(
        'renders no cards when historicalCharges is empty',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          const historicalCharges = <HistoricalCharge>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const HistoricalChargeWindowWrap(
                  colorStops: colorStops,
                  historicalCharges: historicalCharges,
                ),
              ),
            ),
          );

          expect(
            find.byType(HistoricalChargeWindowCard),
            findsNothing,
          );
        },
      );

      testWidgets(
        'renders only the Current card for a single charge that falls outside today',
        (tester) async {
          const colorStops = [
            (Colors.green, 10.0),
            (Colors.red, 30.0),
          ];

          final now = DateTime.now().toUtc();

          // Two days from now, so it's excluded from the 'remaining' slots
          // the Best/Avoid cards search, leaving only Current.
          final historicalCharges = [
            HistoricalCharge(
              validFrom: now.add(
                const Duration(
                  hours: 48,
                ),
              ),
              validTo: now.add(
                const Duration(
                  hours: 48,
                  minutes: 30,
                ),
              ),
              valueExcVat: 20.0,
              valueIncVat: 20.0,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HistoricalChargeWindowWrap(
                  colorStops: colorStops,
                  historicalCharges: historicalCharges,
                ),
              ),
            ),
          );

          final cards = tester.widgetList<HistoricalChargeWindowCard>(
            find.byType(HistoricalChargeWindowCard),
          );

          expect(
            cards.length,
            1,
          );

          expect(
            cards.first.label,
            'Current',
          );
        },
      );
    },
  );
}
