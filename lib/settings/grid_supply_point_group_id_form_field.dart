import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nominatim_api_client/nominatim_api_client.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';

import '../main.dart';

class GridSupplyPointGroupIdFormField extends StatefulWidget {
  const GridSupplyPointGroupIdFormField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;

  final void Function(String?) onChanged;

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
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8.0,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  items: items,
                  initialValue: widget.value,
                  onChanged: widget.onChanged,
                  decoration: const InputDecoration(
                    label: Text('Region'),
                    helper: Text('The area for which prices are shown'),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your region.';
                    }

                    return null;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: 8.0,
                ),
                child: TextButton.icon(
                  onPressed: () async {
                    final client = context.read<OctopusEnergyApiClient>();
                    final messenger = ScaffoldMessenger.of(context);
                    final nominatim = context.read<NominatimApiClient>();

                    if (!await Geolocator.isLocationServiceEnabled()) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Please enable location services.'),
                        ),
                      );

                      return;
                    }

                    var permission = await Geolocator.checkPermission();

                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();

                      if (permission == LocationPermission.denied) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Please allow location permissions.'),
                          ),
                        );

                        return;
                      }
                    }

                    if (permission == LocationPermission.deniedForever) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Please allow location permissions.'),
                        ),
                      );

                      return;
                    }

                    final Position position;

                    try {
                      position = await Geolocator.getCurrentPosition();
                    } catch (e) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Failed to get the location.'),
                        ),
                      );

                      return;
                    }

                    final String postcode;

                    try {
                      final place = await nominatim.reverse(
                        position.latitude,
                        position.longitude,
                      );

                      postcode = place.address!['postcode']!;
                    } catch (e) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Failed to get the postcode.'),
                        ),
                      );

                      return;
                    }

                    final String groupId;

                    try {
                      final list =
                          await client.industry.listIndustryGridSupplyPoints(
                        page: 1,
                        postcode: postcode,
                      );

                      groupId = list.results.first.groupId;
                    } catch (e) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Failed to get the group identifier.'),
                        ),
                      );

                      return;
                    }

                    widget.onChanged(groupId);
                  },
                  icon: Icon(Icons.my_location),
                  label: Text('Detect'),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8.0,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                items: const [],
                onChanged: null,
                decoration: const InputDecoration(
                  label: Text('Region'),
                  helper: Text('The area for which prices are shown'),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: 8.0,
              ),
              child: TextButton.icon(
                onPressed: null,
                icon: Icon(Icons.my_location),
                label: Text('Detect'),
              ),
            ),
          ],
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
