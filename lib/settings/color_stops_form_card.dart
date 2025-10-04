import 'package:flutter/material.dart';

import 'color_stops_form.dart';

class ColorStopsFormCard extends StatelessWidget {
  const ColorStopsFormCard({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Card(
      margin: EdgeInsets.zero,
      child: ColorStopsForm(),
    );
  }
}
