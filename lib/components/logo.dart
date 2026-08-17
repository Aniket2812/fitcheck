import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CompeteLogo extends StatelessWidget {
  const CompeteLogo({super.key, this.color = AppColors.textPrimary});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'fitcheck',
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              'assets/images/fitcheck-logo.png',
              width: 28,
              height: 28,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'fitcheck',
            style: TextStyle(
              fontFamily: 'Jost',
              fontSize: 19,
              fontWeight: FontWeight.w500,
              color: color,
              letterSpacing: -.35,
            ),
          ),
        ],
      ),
    );
  }
}
