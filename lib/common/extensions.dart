extension IterableDoubleExtensions on Iterable<double> {
  double get median {
    final values = [...this]..sort();

    final middle = values.length ~/ 2;

    if (values.length.isOdd) {
      return values[middle];
    }

    return (values[middle - 1] + values[middle]) / 2;
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
