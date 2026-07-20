/// The default hours below threshold, used both as [getHoursBelowThreshold]
/// in `lib/common/functions.dart`'s fallback for when nothing has been
/// persisted yet, and as the today's summary form's starting value before
/// that preference read completes.
const defaultHoursBelowThreshold = 15.00;

/// The default tariff comparison rate, used both as
/// [getTariffComparisonRate] in `lib/common/functions.dart`'s fallback for
/// when nothing has been persisted yet, and as the today's summary form's
/// starting value before that preference read completes.
const defaultTariffComparisonRate = 27.00;
