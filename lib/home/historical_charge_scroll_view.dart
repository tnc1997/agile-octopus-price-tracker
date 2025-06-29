import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import 'historical_charge_list_tile.dart';

class HistoricalChargeScrollView extends StatelessWidget {
  const HistoricalChargeScrollView({
    super.key,
    required this.historicalCharges,
  });

  final List<HistoricalCharge> historicalCharges;

  @override
  Widget build(
    BuildContext context,
  ) {
    final map = groupBy(
      historicalCharges,
      (historicalCharge) {
        return DateFormat.yMMMMEEEEd().format(
          historicalCharge.validFrom!.toLocal(),
        );
      },
    );

    return CustomScrollView(
      slivers: map.entries.map(
        (entry) {
          return SliverMainAxisGroup(
            slivers: [
              PinnedHeaderSliver(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              SliverList.builder(
                itemBuilder: (context, index) {
                  return HistoricalChargeListTile(
                    historicalCharge: entry.value[index],
                  );
                },
                itemCount: entry.value.length,
              ),
            ],
          );
        },
      ).toList(),
    );
  }
}
