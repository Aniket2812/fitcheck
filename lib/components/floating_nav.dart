import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppTab { feed, photos, collections }

class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.active,
    required this.onChange,
    this.onAdd,
  });

  final AppTab active;
  final ValueChanged<AppTab> onChange;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: math.max(safeBottom, AppSpacing.x2) + AppSpacing.x2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.raised.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderDefault, width: 0.7),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A1E1D1B),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavButton(
                  key: const Key('feed-tab'),
                  label: 'Feed',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  active: active == AppTab.feed,
                  onPressed: () => onChange(AppTab.feed),
                ),
                const SizedBox(width: 2),
                _NavButton(
                  key: const Key('photos-tab'),
                  label: 'My photos',
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  active: active == AppTab.photos,
                  onPressed: () => onChange(AppTab.photos),
                ),
                const SizedBox(width: 4),
                _AddButton(onPressed: onAdd ?? () {}),
                const SizedBox(width: 4),
                _NavButton(
                  key: const Key('collections-tab'),
                  label: 'Collections',
                  icon: Icons.folder_outlined,
                  activeIcon: Icons.folder,
                  active: active == AppTab.collections,
                  onPressed: () => onChange(AppTab.collections),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.textPrimary : AppColors.textMuted;

    return Semantics(
      selected: active,
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(active ? activeIcon : icon, size: 22),
          color: color,
          style: ButtonStyle(
            fixedSize: const WidgetStatePropertyAll(
              Size.square(AppSizes.navButton),
            ),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            backgroundColor: WidgetStatePropertyAll(
              active ? AppColors.sunken : Colors.transparent,
            ),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('add-post-button'),
      onPressed: onPressed,
      tooltip: 'Create post',
      icon: const Icon(Icons.add, size: 22),
      color: AppColors.textOnAccent,
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(
          Size.square(AppSizes.navButton),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: const WidgetStatePropertyAll(AppColors.accent),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
    );
  }
}
