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
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.raised.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F191A17),
                  blurRadius: 26,
                  offset: Offset(0, 10),
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
        child: SizedBox.square(
          dimension: AppSizes.navButton,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(AppRadii.medium),
              child: AnimatedContainer(
                duration: AppMotion.standard,
                curve: AppMotion.curve,
                decoration: BoxDecoration(
                  color: active ? AppColors.sunken : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.quick,
                      switchInCurve: AppMotion.curve,
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Icon(
                        active ? activeIcon : icon,
                        key: ValueKey(active),
                        size: 21,
                        color: color,
                      ),
                    ),
                    AnimatedPositioned(
                      duration: AppMotion.standard,
                      curve: AppMotion.curve,
                      bottom: active ? 5 : 2,
                      child: AnimatedOpacity(
                        duration: AppMotion.quick,
                        opacity: active ? 1 : 0,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.fresh,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(dimension: 4),
                        ),
                      ),
                    ),
                  ],
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
    return SizedBox.square(
      dimension: AppSizes.navButton,
      child: Material(
        key: const Key('add-post-button'),
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashColor: AppColors.fresh.withValues(alpha: 0.24),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              size: 23,
              color: AppColors.textOnAccent,
            ),
          ),
        ),
      ),
    );
  }
}
