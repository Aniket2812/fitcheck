import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'avatar.dart';
import 'logo.dart';

class CompeteHeader extends StatelessWidget {
  const CompeteHeader({
    super.key,
    required this.onSearch,
    required this.onProfile,
    this.profileName = 'fitcheck creator',
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
        padding: const EdgeInsets.fromLTRB(14, AppSpacing.x2, 12, 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const CompeteLogo(),
            Row(
              children: [
                SizedBox.square(
                  dimension: AppSizes.hitTarget,
                  child: Material(
                    key: const Key('search-button'),
                    color: AppColors.sunken,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: InkWell(
                      onTap: onSearch,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: const Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
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
