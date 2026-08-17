import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DiagonalProcessingOverlay extends StatefulWidget {
  const DiagonalProcessingOverlay({
    super.key,
    this.label = 'Fitting every piece',
    this.points = const [],
  });

  final String label;
  final List<Offset> points;

  @override
  State<DiagonalProcessingOverlay> createState() =>
      _DiagonalProcessingOverlayState();
}

class _DiagonalProcessingOverlayState extends State<DiagonalProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: AppColors.textPrimary.withValues(alpha: 0.34)),
        CustomPaint(painter: _DiagonalSweepPainter(_controller.value)),
        for (var index = 0; index < widget.points.length; index++)
          _PieceProgressDot(
            key: Key('processing-piece-dot-$index'),
            point: widget.points[index],
            progress: _controller.value,
            delay: index / math.max(widget.points.length, 1),
          ),
        Center(
          child: Semantics(
            liveRegion: true,
            label: '${widget.label}…',
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(width: 5),
                      _AnimatedEllipsis(progress: _controller.value),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PieceProgressDot extends StatelessWidget {
  const _PieceProgressDot({
    super.key,
    required this.point,
    required this.progress,
    required this.delay,
  });

  final Offset point;
  final double progress;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final phase = ((progress - delay) % 1) * math.pi * 2;
    final pulse = (math.sin(phase) + 1) / 2;
    return Align(
      alignment: Alignment(point.dx * 2 - 1, point.dy * 2 - 1),
      child: Transform.scale(
        scale: 0.78 + pulse * 0.28,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82 + pulse * 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.72),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.3 + pulse * 0.35),
                blurRadius: 8 + pulse * 8,
                spreadRadius: pulse * 2,
              ),
            ],
          ),
          child: const SizedBox.square(
            dimension: 14,
            child: Center(
              child: SizedBox.square(
                dimension: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedEllipsis extends StatelessWidget {
  const _AnimatedEllipsis({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var index = 0; index < 3; index++)
          Opacity(
            key: Key('processing-ellipsis-dot-$index'),
            opacity: _opacity(index),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 4),
            ),
          ),
      ],
    ),
  );

  double _opacity(int index) {
    final phase = ((progress * 3) - index) % 3;
    return phase >= 0 && phase < 1 ? 1 : 0.24;
  }
}

class _DiagonalSweepPainter extends CustomPainter {
  const _DiagonalSweepPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final travel = size.width + size.height;
    final offset = progress * (travel + 180) - 180;
    final path = Path()
      ..moveTo(offset - 110, 0)
      ..lineTo(offset, 0)
      ..lineTo(offset - size.height, size.height)
      ..lineTo(offset - size.height - 110, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
  }

  @override
  bool shouldRepaint(_DiagonalSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
