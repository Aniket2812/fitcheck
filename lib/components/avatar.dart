import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.name = 'Mohit', this.size = 32});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initial = trimmedName.isEmpty ? '' : trimmedName[0].toUpperCase();

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.sunken,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderStrong, width: 0.5),
        ),
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Jost',
            fontSize: size * 0.44,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
