import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'header.dart';

class CompeteScreen extends StatelessWidget {
  const CompeteScreen({
    super.key,
    required this.onSearch,
    required this.child,
    required this.onProfile,
    this.profileName = 'fitcheck creator',
    this.profileAvatarUrl,
  });

  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final String profileName;
  final String? profileAvatarUrl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          CompeteHeader(
            onSearch: onSearch,
            onProfile: onProfile,
            profileName: profileName,
            profileAvatarUrl: profileAvatarUrl,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
