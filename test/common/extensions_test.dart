import 'package:agile_octopus_price_tracker/common/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

import '../helpers.dart';

void main() {
  group(
    'IterableHistoricalChargeExtensions',
    () {
      group(
        'averageValueIncVat',
        () {
          test(
            'averages negative and positive values correctly',
            () {
              final historicalCharges = [
                historicalCharge(0, -10),
                historicalCharge(30, 10),
              ];

              expect(
                historicalCharges.averageValueIncVat,
                0,
              );
            },
          );

          test(
            'does not round to an integer when the mean is fractional',
            () {
              final historicalCharges = [
                historicalCharge(0, 10),
                historicalCharge(30, 15),
              ];

              expect(
                historicalCharges.averageValueIncVat,
                12.5,
              );
            },
          );

          test(
            'returns the mean of several historicalCharges',
            () {
              final historicalCharges = [
                historicalCharge(0, 10),
                historicalCharge(30, 20),
                historicalCharge(60, 30),
              ];

              expect(
                historicalCharges.averageValueIncVat,
                20,
              );
            },
          );

          test(
            'returns the value for a single charge',
            () {
              final historicalCharges = [historicalCharge(0, 10)];

              expect(
                historicalCharges.averageValueIncVat,
                10,
              );
            },
          );

          test(
            'throws for an empty list, like .average',
            () {
              expect(
                () => <HistoricalCharge>[].averageValueIncVat,
                throwsStateError,
              );
            },
          );
        },
      );
    },
  );
}
