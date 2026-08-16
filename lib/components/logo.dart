import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CompeteLogo extends StatelessWidget {
  const CompeteLogo({super.key, this.color = AppColors.textPrimary});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        'COMPETE',
        style: TextStyle(
          fontFamily: 'Jost',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 4.2,
        ),
      ),
    );
  }
}
