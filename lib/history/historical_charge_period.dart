import 'package:flutter/material.dart';

/// A preset span the history screen can jump to, shown as a quick-select chip.
///
/// Each preset resolves to a [DateTimeRange] ending today.
enum HistoricalChargePeriod {
  /// The seven days up to and including today.
  sevenDays,

  /// The thirty days up to and including today.
  thirtyDays,

  /// The three calendar months up to and including today.
  threeMonths,

  /// The twelve calendar months up to and including today.
  twelveMonths;
}
