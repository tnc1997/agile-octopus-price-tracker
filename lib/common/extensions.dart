import 'package:collection/collection.dart';
import 'package:octopus_energy_api_client/v1.dart';

extension IterableDoubleExtensions on Iterable<double> {
  /// The median of this iterable.
  ///
  /// Throws a [StateError] if this is empty.
  double get median {
    if (isEmpty) {
      throw StateError('No elements');
    }

    final values = [...this]..sort();

    final middle = values.length ~/ 2;

    if (values.length.isOdd) {
      return values[middle];
    }

    return (values[middle - 1] + values[middle]) / 2;
  }
}

extension IterableHistoricalChargeExtensions on Iterable<HistoricalCharge> {
  /// The arithmetic mean of every charge's [HistoricalCharge.valueIncVat].
  ///
  /// Throws a [StateError] if this is empty, exactly as `.average` does.
  double get averageValueIncVat {
    return map((historicalCharge) => historicalCharge.valueIncVat).average;
  }

  /// The median of every charge's [HistoricalCharge.valueIncVat].
  ///
  /// Throws a [StateError] if this is empty, exactly as `.median` does.
  double get medianValueIncVat {
    return map((historicalCharge) => historicalCharge.valueIncVat).median;
  }
}

extension NumExtensions on num {
  /// https://docs.arduino.cc/language-reference/en/functions/math/map
  double remap(
    num fromLow,
    num fromHigh,
    num toLow,
    num toHigh,
  ) {
    return (this - fromLow) * (toHigh - toLow) / (fromHigh - fromLow) + toLow;
  }
}
