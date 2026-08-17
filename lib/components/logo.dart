import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CompeteLogo extends StatelessWidget {
  const CompeteLogo({super.key, this.color = AppColors.textPrimary});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPETE',
            style: TextStyle(
              fontFamily: 'Jost',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: color,
              letterSpacing: 4.2,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.fresh,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 6),
            ),
          ),
        ],
      ),
    );
  }
}
