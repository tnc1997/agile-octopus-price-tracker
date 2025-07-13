import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'historical_charge_card.dart';
import 'historical_charge_chart_card.dart';
import 'historical_charge_scroll_view_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<PaginatedHistoricalChargeList> _future;

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.data?.results case final historicalCharges?) {
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

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(8.0),
                      sliver: SliverGrid(
                        delegate: SliverChildListDelegate.fixed(
                          [
                            HistoricalChargeCard(
                              historicalCharge: historicalCharges[0],
                              leading: Tooltip(
                                message: 'Current',
                                child: Icon(Icons.circle_outlined),
                              ),
                            ),
                            HistoricalChargeCard(
                              historicalCharge: historicalCharges[1],
                              leading: Tooltip(
                                message: 'Next',
                                child: Icon(Icons.arrow_circle_right_outlined),
                              ),
                            ),
                            HistoricalChargeCard(
                              historicalCharge: minBy(
                                historicalCharges,
                                (historicalCharge) {
                                  return historicalCharge.valueIncVat!;
                                },
                              )!,
                              leading: Tooltip(
                                message: 'Lowest',
                                child: Icon(Icons.arrow_circle_down_outlined),
                              ),
                            ),
                            HistoricalChargeCard(
                              historicalCharge: maxBy(
                                historicalCharges,
                                (historicalCharge) {
                                  return historicalCharge.valueIncVat!;
                                },
                              )!,
                              leading: Tooltip(
                                message: 'Highest',
                                child: Icon(Icons.arrow_circle_up_outlined),
                              ),
                            ),
                          ],
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth > 768 ? 4 : 2,
                          mainAxisSpacing: 16.0,
                          crossAxisSpacing: 16.0,
                          childAspectRatio: 2.0,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(8.0),
                      sliver: SliverGrid(
                        delegate: SliverChildListDelegate.fixed(
                          [
                            HistoricalChargeChartCard(
                              historicalCharges: historicalCharges,
                            ),
                            HistoricalChargeScrollViewCard(
                              historicalCharges: historicalCharges,
                            ),
                          ],
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth > 768 ? 2 : 1,
                          mainAxisSpacing: 16.0,
                          crossAxisSpacing: 16.0,
                          childAspectRatio: 1.0,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }

        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    final client = context.read<OctopusEnergyApiClient>();
    final preferences = context.read<SharedPreferencesAsync>();

    _future = (
      preferences.getString('import_product_code'),
      preferences.getString('import_tariff_code'),
    ).wait.then(
      (value) {
        return client.products.listElectricityTariffStandardUnitRates(
          value.$1!,
          value.$2!,
          page: 1,
          pageSize: 96,
          periodFrom: DateTime.now().toUtc(),
        );
      },
    );
  }
}
