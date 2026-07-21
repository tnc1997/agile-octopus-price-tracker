import 'package:flutter/material.dart';

/// The "high" price stop's color, used both as [getColorStops] in
/// `lib/common/functions.dart`'s fallback for when nothing has been
/// persisted yet, and as the color stops form's starting value before that
/// preference read completes.
const defaultHighColor = Color(0xffff0000);

/// The "high" price stop's threshold, in p/kWh, used both as
/// [getColorStops] in `lib/common/functions.dart`'s fallback for when
/// nothing has been persisted yet, and as the color stops form's starting
/// value before that preference read completes.
const defaultHighPrice = 30.00;

/// The default hours below threshold, used both as [getHoursBelowThreshold]
/// in `lib/common/functions.dart`'s fallback for when nothing has been
/// persisted yet, and as the today's summary form's starting value before
/// that preference read completes.
const defaultHoursBelowThreshold = 15.00;

/// The "low" price stop's color, used both as [getColorStops] in
/// `lib/common/functions.dart`'s fallback for when nothing has been
/// persisted yet, and as the color stops form's starting value before that
/// preference read completes.
const defaultLowColor = Color(0xff00ff00);

/// The "low" price stop's threshold, in p/kWh, used both as [getColorStops]
/// in `lib/common/functions.dart`'s fallback for when nothing has been
/// persisted yet, and as the color stops form's starting value before that
/// preference read completes.
const defaultLowPrice = 10.00;

/// The "medium" price stop's color, used both as [getColorStops] in
/// `lib/common/functions.dart`'s fallback for when nothing has been
/// persisted yet, and as the color stops form's starting value before that
/// preference read completes.
const defaultMediumColor = Color(0xffffff00);

/// The "medium" price stop's threshold, in p/kWh, used both as
/// [getColorStops] in `lib/common/functions.dart`'s fallback for when
/// nothing has been persisted yet, and as the color stops form's starting
/// value before that preference read completes.
const defaultMediumPrice = 20.00;

/// The negative-price stop's color, used both as [getColorStops] in
/// `lib/common/functions.dart`'s fallback for when nothing has been
/// persisted yet, and as the color stops form's starting value before that
/// preference read completes.
const defaultNegativeColor = Color(0xff00ffff);

/// The negative-price stop's displayed threshold, in p/kWh, used by the
/// color stops form as its starting value before that preference read
/// completes. Unlike the other three default prices, this is never compared
/// against a saved value or written back to preferences — the negative
/// stop's price is always persisted as the fixed `-1.00` sentinel.
const defaultNegativePrice = 0.00;

/// The default tariff comparison rate, used both as
/// [getTariffComparisonRate] in `lib/common/functions.dart`'s fallback for
/// when nothing has been persisted yet, and as the today's summary form's
/// starting value before that preference read completes.
const defaultTariffComparisonRate = 27.00;
