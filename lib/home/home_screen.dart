import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'historical_charge_list_tile.dart';

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
  late final _controller = StreamController<PaginatedHistoricalChargeList>();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder(
          stream: _controller.stream,
          builder: (context, snapshot) {
            if (snapshot.data?.results case final results?) {
              results.sort(
                (a, b) {
                  if (a.validFrom case final a?) {
                    if (b.validFrom case final b?) {
                      return a.compareTo(b);
                    }
                  }

                  return 0;
                },
              );

              return RefreshIndicator(
                child: ListView.builder(
                  itemBuilder: (context, index) {
                    return HistoricalChargeListTile(
                      historicalCharge: results[index],
                    );
                  },
                  itemCount: results.length,
                ),
                onRefresh: () async {
                  await _get().then(_controller.add);
                },
              );
            }

            return Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _get().then(_controller.add);
  }

  Future<PaginatedHistoricalChargeList> _get() async {
    final client = context.read<OctopusEnergyApiClient>();
    final preferences = context.read<SharedPreferencesAsync>();

    final productCode = await preferences.getString('import_product_code');
    final tariffCode = await preferences.getString('import_tariff_code');

    return client.products.listElectricityTariffStandardUnitRates(
      productCode!,
      tariffCode!,
      page: 1,
      pageSize: 96,
      periodFrom: DateTime.now().toUtc(),
    );
  }
}
