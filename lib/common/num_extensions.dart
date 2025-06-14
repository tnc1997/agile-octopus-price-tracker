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
