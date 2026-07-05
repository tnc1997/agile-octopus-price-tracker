import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'historical_charge_chart_card.dart';
import 'historical_charge_period.dart';
import 'historical_charge_period_segmented_button.dart';
import 'historical_charge_sliver_list.dart';
import 'historical_charge_summary.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
  });

  @override
  State<HistoryScreen> createState() {
    return _HistoryScreenState();
  }
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// The Octopus Energy API client, read once from the provider in [initState].
  late final OctopusEnergyApiClient _client;

  /// The shared preferences store, read once from the provider in [initState].
  ///
  /// Source of the `import_product_code` and `import_tariff_code` the charges
  /// are fetched for.
  late final SharedPreferencesAsync _preferences;

  /// The start and end dates the charges are shown for.
  ///
  /// Both are local calendar days; the end day is inclusive.
  late DateTimeRange _dateRange;

  /// The preset the current range came from, or null when a custom range was
  /// picked from the date range picker; drives which button is selected.
  HistoricalChargePeriod? _period;

  /// The charges for [_dateRange], or null while a load is in flight.
  ///
  /// Resolved into state rather than driven by a [FutureBuilder] so the daily
  /// summary can be a lazily-built [SliverList] directly among the slivers.
  List<HistoricalCharge>? _historicalCharges;

  /// Incremented on each load so a slow earlier request cannot overwrite the
  /// results of a later one if it completes out of order.
  int _generation = 0;

  @override
  Widget build(
    BuildContext context,
  ) {
    final historicalCharges = _historicalCharges;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsGeometry.all(8.0),
            sliver: SliverToBoxAdapter(
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    '${DateFormat.yMMMMd().format(
                      _dateRange.start,
                    )} – ${DateFormat.yMMMMd().format(
                      _dateRange.end,
                    )}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: _showDateRangePicker,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsetsGeometry.all(8.0),
            sliver: SliverToBoxAdapter(
              child: HistoricalChargePeriodSegmentedButton(
                selected: _period,
                onSelectionChanged: _selectPeriod,
              ),
            ),
          ),
          if (historicalCharges != null)
            if (historicalCharges.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsetsGeometry.all(8.0),
                sliver: SliverToBoxAdapter(
                  child: HistoricalChargeSummary(
                    historicalCharges: historicalCharges,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsetsGeometry.all(8.0),
                sliver: SliverToBoxAdapter(
                  child: HistoricalChargeChartCard(
                    historicalCharges: historicalCharges,
                  ),
                ),
              ),
            ],
          if (historicalCharges == null)
            const SliverPadding(
              padding: EdgeInsets.all(8.0),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (historicalCharges.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.all(8.0),
              sliver: SliverToBoxAdapter(
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No data for the selected range.',
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(8.0),
              sliver: HistoricalChargeSliverList(
                historicalCharges: historicalCharges,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _client = context.read<OctopusEnergyApiClient>();
    _preferences = context.read<SharedPreferencesAsync>();

    // Default to the last week up to and including today.
    final period = _period = HistoricalChargePeriod.sevenDays;
    _dateRange = _getRangeEndingOn(period, _getToday());

    _load();
  }

  /// Fetches the confirmed unit rates whose slots fall within [dateRange].
  ///
  /// The end day is inclusive, so the query runs up to the start of the
  /// following day to cover its final slots. The API paginates the results, so
  /// the pages are followed until there are no more (the response's `next` is
  /// null), and the combined charges are sorted ascending by `validFrom` so the
  /// summary, chart and list all read them in order.
  Future<List<HistoricalCharge>> _getHistoricalCharges(
    DateTimeRange dateRange,
  ) async {
    final periodFrom = dateRange.start;
    final periodTo = dateRange.end.add(const Duration(days: 1));

    final (productCode, tariffCode) = await (
      _preferences.getString('import_product_code'),
      _preferences.getString('import_tariff_code'),
    ).wait;

    final historicalCharges = <HistoricalCharge>[];

    var page = 1;

    while (true) {
      final result =
          await _client.products.listElectricityTariffStandardUnitRates(
        productCode!,
        tariffCode!,
        page: page,
        pageSize: 1500,
        periodFrom: periodFrom,
        periodTo: periodTo,
      );

      historicalCharges.addAll(result.results);

      if (result.next == null) {
        break;
      }

      page++;
    }

    historicalCharges.sort(
      (a, b) {
        if (a.validFrom case final a?) {
          if (b.validFrom case final b?) {
            return a.compareTo(b);
          }
        }

        return 0;
      },
    );

    return historicalCharges;
  }

  /// The range the [period] covers, ending on [today] (inclusive).
  ///
  /// The day-based [period]s count inclusively — `7 Days` ending on 7 Jul spans
  /// 1–7 Jul — so they subtract one less than their length. The longer [period]s
  /// step back by calendar months or years, letting [DateTime] roll shorter
  /// months over as needed.
  DateTimeRange _getRangeEndingOn(
    HistoricalChargePeriod period,
    DateTime today,
  ) {
    return switch (period) {
      HistoricalChargePeriod.sevenDays => DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        ),
      HistoricalChargePeriod.thirtyDays => DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        ),
      HistoricalChargePeriod.threeMonths => DateTimeRange(
          start: DateTime(today.year, today.month - 3, today.day),
          end: today,
        ),
      HistoricalChargePeriod.twelveMonths => DateTimeRange(
          start: DateTime(today.year - 1, today.month, today.day),
          end: today,
        ),
    };
  }

  /// Today as a local calendar day (no time component), used as the anchor for
  /// the historical charge periods and the upper bound of the date range picker.
  DateTime _getToday() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  /// Fetches the charges for [_dateRange] and stores them in state.
  ///
  /// A generation token guards against a slow earlier load completing after a
  /// later one and overwriting it, and a failure degrades to an empty result
  /// (shown as the empty state) rather than leaving the spinner up forever.
  void _load() {
    final generation = ++_generation;

    _getHistoricalCharges(_dateRange).then((historicalCharges) {
      if (!mounted || generation != _generation) {
        return;
      }

      setState(() {
        _historicalCharges = historicalCharges;
      });
    }).catchError((_) {
      if (!mounted || generation != _generation) {
        return;
      }

      setState(() {
        _historicalCharges = const [];
      });
    });
  }

  /// Switches to [period]'s range and refetches the charges.
  void _selectPeriod(
    HistoricalChargePeriod period,
  ) {
    setState(() {
      _period = period;
      _dateRange = _getRangeEndingOn(period, _getToday());
      _historicalCharges = null;
    });

    _load();
  }

  /// Prompts the user to pick a custom start and end date and, when they do,
  /// clears the selected preset and refetches the charges for the chosen range.
  Future<void> _showDateRangePicker() async {
    final dateRange = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2018),
      lastDate: _getToday(),
    );

    if (dateRange != null) {
      setState(() {
        _period = null;
        _dateRange = dateRange;
        _historicalCharges = null;
      });

      _load();
    }
  }
}
