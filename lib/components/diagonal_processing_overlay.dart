import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DiagonalProcessingOverlay extends StatefulWidget {
  const DiagonalProcessingOverlay({
    super.key,
    this.label = 'STYLING YOUR LOOK',
  });

  final String label;

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
        Center(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.raised,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
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
