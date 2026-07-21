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
/// stop's price is always persisted as the fixed [negativePriceSentinel].
const defaultNegativePrice = 0.00;

/// The default tariff comparison rate, used both as
/// [getTariffComparisonRate] in `lib/common/functions.dart`'s fallback for
/// when nothing has been persisted yet, and as the today's summary form's
/// starting value before that preference read completes.
const defaultTariffComparisonRate = 27.00;

/// The known Agile Octopus import product codes, mapped to the label each
/// is shown under in `ImportProductCodeFormField`'s drop-down.
///
/// A map rather than a list of pairs so looking a code's label up — e.g. to
/// show it while the field is disabled — is an O(1) lookup instead of a
/// linear scan.
const importProductCodeLabels = {
  'AGILE-24-10-01': 'Agile Octopus October 2024 v1',
  'AGILE-24-04-03': 'Agile Octopus April 2024 v1',
  'AGILE-23-12-06': 'Agile Octopus December 2023 v1',
  'AGILE-FLEX-22-11-25': 'Agile Octopus November 2022 v1',
  'AGILE-22-08-31': 'Agile Octopus August 2022 v1',
  'AGILE-22-07-22': 'Agile Octopus July 2022 v1',
  'AGILE-18-02-21': 'Agile Octopus February 2018',
};

/// The fixed price persisted (and used as the fallback stop) for the
/// negative-price color stop. Not a default in the same sense as the
/// `defaultXPrice` constants above — it is always used verbatim, never
/// compared against or overwritten by a user-entered value, since the
/// negative stop's threshold isn't user-editable.
const negativePriceSentinel = -1.00;
