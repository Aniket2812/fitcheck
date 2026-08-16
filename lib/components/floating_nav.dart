import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppTab { feed, saved }

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
      bottom: math.max(safeBottom, AppSpacing.x3) + AppSpacing.x3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            key: const Key('feed-tab'),
            label: 'Feed',
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            active: active == AppTab.feed,
            onPressed: () => onChange(AppTab.feed),
          ),
          const SizedBox(width: AppSpacing.x3),
          _AddButton(onPressed: onAdd ?? () {}),
          const SizedBox(width: AppSpacing.x3),
          _NavButton(
            key: const Key('saved-tab'),
            label: 'Saved',
            icon: Icons.bookmark_border,
            activeIcon: Icons.bookmark,
            active: active == AppTab.saved,
            onPressed: () => onChange(AppTab.saved),
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
            backgroundColor: const WidgetStatePropertyAll(AppColors.raised),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.large),
                side: BorderSide(
                  color: active
                      ? AppColors.borderStrong
                      : AppColors.borderDefault,
                  width: 0.5,
                ),
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
      icon: const Icon(Icons.add, size: 24),
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
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
        ),
      ),
    );
  }
}
