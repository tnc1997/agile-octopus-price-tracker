import 'package:flutter/material.dart';

import 'tariff_form.dart';

class TariffFormCard extends StatelessWidget {
  const TariffFormCard({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Card(
      margin: EdgeInsets.zero,
      child: TariffForm(),
    );
  }
}
