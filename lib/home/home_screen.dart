import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';

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
            if (snapshot.data case final data?) {
              data.results.sort(
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
                    charge: data.results[index],
                  );
                },
                itemCount: data.results.length,
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

    _future = client.products.listElectricityTariffStandardUnitRates(
      'AGILE-24-10-01',
      'E-1R-AGILE-24-10-01-E',
      page: 1,
      pageSize: 96,
      periodFrom: DateTime.now().toUtc(),
    );
  }
}
