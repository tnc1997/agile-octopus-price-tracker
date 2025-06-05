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
  late final Future<PaginatedHistoricalChargeList> _future;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder(
          future: _future,
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

              return ListView.builder(
                itemBuilder: (context, index) {
                  return HistoricalChargeListTile(
                    historicalCharge: results[index],
                  );
                },
                itemCount: results.length,
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
