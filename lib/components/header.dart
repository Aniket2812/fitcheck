import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'avatar.dart';
import 'logo.dart';

class CompeteHeader extends StatelessWidget {
  const CompeteHeader({
    super.key,
    required this.onSearch,
    required this.onProfile,
    this.profileName = 'YouCam Creator',
    this.profileAvatarUrl,
  });

  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final String profileName;
  final String? profileAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x3,
          AppSpacing.x4,
          AppSpacing.x3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const CompeteLogo(),
            Row(
              children: [
                IconButton(
                  key: const Key('search-button'),
                  onPressed: onSearch,
                  tooltip: 'Search',
                  icon: const Icon(Icons.search, size: 22),
                  color: AppColors.textPrimary,
                  style: const ButtonStyle(
                    fixedSize: WidgetStatePropertyAll(
                      Size.square(AppSizes.hitTarget),
                    ),
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                    overlayColor: WidgetStatePropertyAll(Colors.transparent),
                  ),
                ),
                IconButton(
                  key: const Key('profile-button'),
                  onPressed: onProfile,
                  tooltip: 'Profile',
                  icon: Avatar(name: profileName, imageUrl: profileAvatarUrl),
                  style: const ButtonStyle(
                    fixedSize: WidgetStatePropertyAll(
                      Size.square(AppSizes.hitTarget),
                    ),
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                    overlayColor: WidgetStatePropertyAll(Colors.transparent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
