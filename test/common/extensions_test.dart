import 'package:agile_octopus_price_tracker/common/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_energy_api_client/v1.dart';

void main() {
  group(
    'IterableDoubleExtensions',
    () {
      group(
        'median',
        () {
          test(
            'returns the average of the two middle values for an even-length list',
            () {
              expect(
                [100.0, 10.0, 20.0, 30.0].median,
                25,
              );
            },
          );

          test(
            'returns the middle value for an odd-length list',
            () {
              expect(
                [100.0, 10.0, 20.0].median,
                20,
              );
            },
          );

          test(
            'returns the value for a single-element list',
            () {
              expect(
                [10.0].median,
                10,
              );
            },
          );

          test(
            'throws a StateError for an empty list',
            () {
              expect(
                () => <double>[].median,
                throwsStateError,
              );
            },
          );
        },
      );
    },
  );

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
                HistoricalCharge(
                  validFrom: DateTime.utc(1970),
                  validTo: DateTime.utc(1970, 1, 1, 0, 30),
                  valueExcVat: -10,
                  valueIncVat: -10,
                ),
                HistoricalCharge(
                  validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                  validTo: DateTime.utc(1970, 1, 1, 1, 0),
                  valueExcVat: 10,
                  valueIncVat: 10,
                ),
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
                HistoricalCharge(
                  validFrom: DateTime.utc(1970),
                  validTo: DateTime.utc(1970, 1, 1, 0, 30),
                  valueExcVat: 10,
                  valueIncVat: 10,
                ),
                HistoricalCharge(
                  validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                  validTo: DateTime.utc(1970, 1, 1, 1, 0),
                  valueExcVat: 15,
                  valueIncVat: 15,
                ),
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
                HistoricalCharge(
                  validFrom: DateTime.utc(1970),
                  validTo: DateTime.utc(1970, 1, 1, 0, 30),
                  valueExcVat: 10,
                  valueIncVat: 10,
                ),
                HistoricalCharge(
                  validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                  validTo: DateTime.utc(1970, 1, 1, 1, 0),
                  valueExcVat: 20,
                  valueIncVat: 20,
                ),
                HistoricalCharge(
                  validFrom: DateTime.utc(1970, 1, 1, 1, 0),
                  validTo: DateTime.utc(1970, 1, 1, 1, 30),
                  valueExcVat: 30,
                  valueIncVat: 30,
                ),
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
              final historicalCharges = [
                HistoricalCharge(
                  validFrom: DateTime.utc(1970),
                  validTo: DateTime.utc(1970, 1, 1, 0, 30),
                  valueExcVat: 10,
                  valueIncVat: 10,
                )
              ];

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

      group(
        'medianValueIncVat',
        () {
          test(
            'is unaffected by input order',
            () {
              final historicalCharges = [
                HistoricalCharge(
                  validFrom: DateTime.utc(1970),
                  validTo: DateTime.utc(1970, 1, 1, 0, 30),
                  valueExcVat: 30,
                  valueIncVat: 30,
                ),
                HistoricalCharge(
                  validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                  validTo: DateTime.utc(1970, 1, 1, 1, 0),
                  valueExcVat: 10,
                  valueIncVat: 10,
                ),
                HistoricalCharge(
                  validFrom: DateTime.utc(1970, 1, 1, 1, 0),
                  validTo: DateTime.utc(1970, 1, 1, 1, 30),
                  valueExcVat: 20,
                  valueIncVat: 20,
                ),
              ];

              expect(
                historicalCharges.medianValueIncVat,
                20,
              );
            },
          );

          test(
            'returns the average of the two middle values for an even-length list',
            () {
              final historicalCharges = [
                HistoricalCharge(
                  validFrom: DateTime.utc(1970),
                  validTo: DateTime.utc(1970, 1, 1, 0, 30),
                  valueExcVat: 100,
                  valueIncVat: 100,
                ),
                HistoricalCharge(
                  validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                  validTo: DateTime.utc(1970, 1, 1, 1, 0),
                  valueExcVat: 10,
                  valueIncVat: 10,
                ),
                HistoricalCharge(
                  validFrom: DateTime.utc(1970, 1, 1, 1, 0),
                  validTo: DateTime.utc(1970, 1, 1, 1, 30),
                  valueExcVat: 20,
                  valueIncVat: 20,
                ),
                HistoricalCharge(
                  validFrom: DateTime.utc(1970, 1, 1, 1, 30),
                  validTo: DateTime.utc(1970, 1, 1, 2, 0),
                  valueExcVat: 30,
                  valueIncVat: 30,
                ),
              ];

              expect(
                historicalCharges.medianValueIncVat,
                25,
              );
            },
          );

          test(
            'returns the middle value for an odd-length list',
            () {
              final historicalCharges = [
                HistoricalCharge(
                  validFrom: DateTime.utc(1970),
                  validTo: DateTime.utc(1970, 1, 1, 0, 30),
                  valueExcVat: 100,
                  valueIncVat: 100,
                ),
                HistoricalCharge(
                  validFrom: DateTime.utc(1970, 1, 1, 0, 30),
                  validTo: DateTime.utc(1970, 1, 1, 1, 0),
                  valueExcVat: 10,
                  valueIncVat: 10,
                ),
                HistoricalCharge(
                  validFrom: DateTime.utc(1970, 1, 1, 1, 0),
                  validTo: DateTime.utc(1970, 1, 1, 1, 30),
                  valueExcVat: 20,
                  valueIncVat: 20,
                ),
              ];

              expect(
                historicalCharges.medianValueIncVat,
                20,
              );
            },
          );

          test(
            'returns the value for a single charge',
            () {
              final historicalCharges = [
                HistoricalCharge(
                  validFrom: DateTime.utc(1970),
                  validTo: DateTime.utc(1970, 1, 1, 0, 30),
                  valueExcVat: 10,
                  valueIncVat: 10,
                )
              ];

              expect(
                historicalCharges.medianValueIncVat,
                10,
              );
            },
          );

          test(
            'throws a StateError for an empty list, like .median',
            () {
              expect(
                () => <HistoricalCharge>[].medianValueIncVat,
                throwsStateError,
              );
            },
          );
        },
      );
    },
  );
}
