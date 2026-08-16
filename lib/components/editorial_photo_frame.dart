import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Gives every outfit photo the same warm editorial studio presentation.
///
/// The source photograph stays untouched inside the mount, so garment
/// hotspots and generated try-on results retain their exact coordinates.
class EditorialPhotoFrame extends StatelessWidget {
  const EditorialPhotoFrame({
    super.key,
    required this.child,
    required this.aspectRatio,
    this.inset = 7,
    this.borderRadius = 18,
    this.photoRadius = 12,
    this.label,
  });

  final Widget child;
  final double aspectRatio;
  final double inset;
  final double borderRadius;
  final double photoRadius;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final labelHeight = label == null ? 0.0 : 24.0;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F0E9),
            image: const DecorationImage(
              image: AssetImage('assets/images/editorial-studio-paper.png'),
              fit: BoxFit.cover,
            ),
            border: Border.all(color: const Color(0x1F312D28)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  inset,
                  inset,
                  inset,
                  inset + labelHeight,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(photoRadius),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2B312B24),
                        blurRadius: 16,
                        offset: Offset(0, 7),
                      ),
                      BoxShadow(
                        color: Color(0x14FFFFFF),
                        blurRadius: 1,
                        offset: Offset(0, -1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(photoRadius),
                    child: ColoredBox(
                      color: AppColors.raised,
                      child: SizedBox.expand(child: child),
                    ),
                  ),
                ),
              ),
              if (label case final value?)
                Positioned(
                  left: inset + 2,
                  right: inset + 2,
                  bottom: 4,
                  child: Row(
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF716B62),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.auto_awesome,
                        size: 11,
                        color: Color(0xFF716B62),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
