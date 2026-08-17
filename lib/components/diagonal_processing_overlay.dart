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
          _PieceSparkleMarker(
            key: Key('processing-piece-sparkle-$index'),
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
                      const SizedBox(width: 8),
                      _AnimatedProgressBars(progress: _controller.value),
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

class _PieceSparkleMarker extends StatelessWidget {
  const _PieceSparkleMarker({
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
      child: Transform.translate(
        offset: Offset(0, 2 - pulse * 4),
        child: Transform.rotate(
          angle: (pulse - 0.5) * 0.12,
          child: Transform.scale(
            scale: 0.84 + pulse * 0.2,
            child: Opacity(
              opacity: 0.58 + pulse * 0.42,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 24,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.65),
                    blurRadius: 12 + pulse * 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedProgressBars extends StatelessWidget {
  const _AnimatedProgressBars({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 13,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < 3; index++)
          Container(
            key: Key('processing-wave-bar-$index'),
            width: 3,
            height: _height(index),
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
      ],
    ),
  );

  double _height(int index) {
    final phase = (progress + index * 0.18) * math.pi * 2;
    return 4 + ((math.sin(phase) + 1) / 2) * 8;
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
