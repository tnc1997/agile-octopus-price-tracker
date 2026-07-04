import 'package:agile_octopus_price_tracker/forecast/price_forecast_model_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart';

// These tests pin the feature-engineering contract PriceForecastModelService.
// getFeatures must reproduce from train_price_forecast_model.py: the column
// order, the Europe/London-derived timestamp features, and the GSP ordinal
// encoding. They deliberately do not run inference — the onnxruntime native
// library is unavailable under `flutter test`, and export parity is verified by
// script/export_price_forecast_model.py — so they exercise only the pure,
// device-independent half of a prediction, which is where a silent drift from
// the training contract would hide.
void main() {
  group(
    'PriceForecastModelService',
    () {
      setUpAll(
        () {
          initializeTimeZones();
        },
      );

      group(
        'getFeatures',
        () {
          test(
            'accepts both the underscored group-identifier form and the bare letter',
            () {
              final underscored = PriceForecastModelService.getFeatures(
                gsp: '_C',
                dateTime: DateTime.utc(2026, 1, 1),
                embeddedWindMw: 0,
                embeddedSolarMw: 0,
                windMw: 0,
              );

              final bare = PriceForecastModelService.getFeatures(
                gsp: 'C',
                dateTime: DateTime.utc(2026, 1, 1),
                embeddedWindMw: 0,
                embeddedSolarMw: 0,
                windMw: 0,
              );

              expect(underscored, bare);
            },
          );

          test(
            'builds the feature vector in the trained column order',
            () {
              // 2026-07-01 is a Wednesday; British Summer Time, so 12:15Z is 13:15
              // local — half-hour slot 26, a weekday, off-peak, July.
              final features = PriceForecastModelService.getFeatures(
                gsp: '_C',
                dateTime: DateTime.utc(2026, 7, 1, 12, 15),
                embeddedWindMw: 100,
                embeddedSolarMw: 200,
                windMw: 300,
              );

              // time_of_day, is_weekend, is_peak, month, gsp, embedded_wind,
              // embedded_solar, wind — London is GSP code 2 (A -> 0, B -> 1, C -> 2).
              expect(
                features,
                [26.0, 0.0, 0.0, 7.0, 2.0, 100.0, 200.0, 300.0],
              );
            },
          );

          test(
            'derives the timestamp features in Europe/London, not UTC',
            () {
              // Greenwich Mean Time, so 2026-01-01 00:00Z is 00:00 local — slot 0,
              // January. The winter counterpart to the summer case, where the same
              // instant would land an hour off if derived in the wrong zone.
              final features = PriceForecastModelService.getFeatures(
                gsp: '_C',
                dateTime: DateTime.utc(2026, 1, 1, 0, 0),
                embeddedWindMw: 0,
                embeddedSolarMw: 0,
                windMw: 0,
              );

              expect(
                features.sublist(0, 5),
                [0.0, 0.0, 0.0, 1.0, 2.0],
              );
            },
          );

          test(
            'flags the weekend and the evening peak in local time',
            () {
              // 2026-07-04 is a Saturday; British Summer Time, so 16:30Z is 17:30
              // local — slot 35, a weekend, inside the 16:00-19:00 peak window.
              final features = PriceForecastModelService.getFeatures(
                gsp: 'C',
                dateTime: DateTime.utc(2026, 7, 4, 16, 30),
                embeddedWindMw: 0,
                embeddedSolarMw: 0,
                windMw: 0,
              );

              expect(
                features.sublist(0, 5),
                [35.0, 1.0, 1.0, 7.0, 2.0],
              );
            },
          );

          test(
            'floors the time of day to the half hour',
            () {
              // 09:29 local is still slot 18 (hour*2); 09:30 steps to slot 19.
              final before = PriceForecastModelService.getFeatures(
                gsp: 'C',
                dateTime: DateTime.utc(2026, 1, 1, 9, 29),
                embeddedWindMw: 0,
                embeddedSolarMw: 0,
                windMw: 0,
              );

              final after = PriceForecastModelService.getFeatures(
                gsp: 'C',
                dateTime: DateTime.utc(2026, 1, 1, 9, 30),
                embeddedWindMw: 0,
                embeddedSolarMw: 0,
                windMw: 0,
              );

              expect(before.first, 18.0);
              expect(after.first, 19.0);
            },
          );

          test(
            'ordinal-encodes the region against the trained code list',
            () {
              // A is the first code (0) and P the last (13).
              double code(String gsp) {
                return PriceForecastModelService.getFeatures(
                  gsp: gsp,
                  dateTime: DateTime.utc(2026, 1, 1),
                  embeddedWindMw: 0,
                  embeddedSolarMw: 0,
                  windMw: 0,
                )[4];
              }

              expect(code('A'), 0.0);
              expect(code('P'), 13.0);
            },
          );

          test(
            'throws for an unknown region',
            () {
              expect(
                () => PriceForecastModelService.getFeatures(
                  gsp: 'Z',
                  dateTime: DateTime.utc(2026, 1, 1),
                  embeddedWindMw: 0,
                  embeddedSolarMw: 0,
                  windMw: 0,
                ),
                throwsArgumentError,
              );
            },
          );
        },
      );
    },
  );
}
