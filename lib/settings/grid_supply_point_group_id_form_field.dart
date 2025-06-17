import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';

class GridSupplyPointGroupIdFormField extends StatefulWidget {
  const GridSupplyPointGroupIdFormField({
    super.key,
    required this.notifier,
  });

  final ValueNotifier<String?> notifier;

  @override
  State<GridSupplyPointGroupIdFormField> createState() {
    return _GridSupplyPointGroupIdFormFieldState();
  }
}

class _GridSupplyPointGroupIdFormFieldState
    extends State<GridSupplyPointGroupIdFormField> {
  late final Future<List<GridSupplyPoint>?> _future;

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data?.map(
          (point) {
            return DropdownMenuItem<String>(
              value: point.groupId,
              child: Text(
                switch (point.groupId) {
                  GridSupplyPointGroupIds.eastMidlands =>
                    GridSupplyPointGroupNames.eastMidlands,
                  GridSupplyPointGroupIds.easternEngland =>
                    GridSupplyPointGroupNames.easternEngland,
                  GridSupplyPointGroupIds.london =>
                    GridSupplyPointGroupNames.london,
                  GridSupplyPointGroupIds.merseysideAndNorthernWales =>
                    GridSupplyPointGroupNames.merseysideAndNorthernWales,
                  GridSupplyPointGroupIds.northEasternEngland =>
                    GridSupplyPointGroupNames.northEasternEngland,
                  GridSupplyPointGroupIds.northWesternEngland =>
                    GridSupplyPointGroupNames.northWesternEngland,
                  GridSupplyPointGroupIds.northernScotland =>
                    GridSupplyPointGroupNames.northernScotland,
                  GridSupplyPointGroupIds.southEasternEngland =>
                    GridSupplyPointGroupNames.southEasternEngland,
                  GridSupplyPointGroupIds.southWesternEngland =>
                    GridSupplyPointGroupNames.southWesternEngland,
                  GridSupplyPointGroupIds.southernEngland =>
                    GridSupplyPointGroupNames.southernEngland,
                  GridSupplyPointGroupIds.southernScotland =>
                    GridSupplyPointGroupNames.southernScotland,
                  GridSupplyPointGroupIds.southernWales =>
                    GridSupplyPointGroupNames.southernWales,
                  GridSupplyPointGroupIds.westMidlands =>
                    GridSupplyPointGroupNames.westMidlands,
                  GridSupplyPointGroupIds.yorkshire =>
                    GridSupplyPointGroupNames.yorkshire,
                  _ => 'Unknown',
                },
              ),
            );
          },
        ).toList();

        if (items != null) {
          return ValueListenableBuilder(
            valueListenable: widget.notifier,
            builder: (context, value, child) {
              return DropdownButtonFormField<String>(
                items: items,
                value: value,
                onChanged: (value) {
                  widget.notifier.value = value;
                },
                decoration: const InputDecoration(
                  label: Text('Region'),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your region.';
                  }

                  return null;
                },
              );
            },
          );
        }

        return DropdownButtonFormField<String>(
          items: const [],
          onChanged: null,
          decoration: const InputDecoration(
            label: Text('Region'),
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    final client = context.read<OctopusEnergyApiClient>();

    _future = client.industry.listIndustryGridSupplyPoints().then(
      (value) {
        return value.results;
      },
    );
  }
}
