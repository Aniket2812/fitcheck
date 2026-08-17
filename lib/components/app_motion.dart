import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A lightweight one-time entrance used for content that appears after an
/// async load. It keeps its completed state across ordinary parent rebuilds.
class AppReveal extends StatelessWidget {
  const AppReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 10),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.relaxed + delay,
    curve: Interval(
      delay.inMilliseconds /
          (AppMotion.relaxed.inMilliseconds + delay.inMilliseconds),
      1,
      curve: AppMotion.curve,
    ),
    child: RepaintBoundary(child: child),
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(offset.dx * (1 - value), offset.dy * (1 - value)),
        child: child,
      ),
    ),
  );
}

class AppLoadingField extends StatefulWidget {
  const AppLoadingField({
    super.key,
    required this.child,
    this.borderRadius = AppRadii.large,
  });

  final Widget child;
  final double borderRadius;

  @override
  State<AppLoadingField> createState() => _AppLoadingFieldState();
}

class _AppLoadingFieldState extends State<AppLoadingField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.8 + _controller.value * 3.6, -0.2),
            end: Alignment(-0.8 + _controller.value * 3.6, 0.2),
            colors: const [
              AppColors.sunken,
              Color(0xFFFAFBF6),
              AppColors.sunken,
            ],
            stops: const [0, 0.5, 1],
          ).createShader(bounds),
          child: child,
        ),
      ),
    ),
  );
}
