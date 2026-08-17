import 'package:flutter/material.dart';

import '../models/social_post.dart';
import '../theme/app_theme.dart';
import 'garment_product_dialog.dart';

class OutfitPostImage extends StatelessWidget {
  const OutfitPostImage({
    super.key,
    required this.post,
    this.onOpenPost,
    this.borderRadius = 0,
  });

  final SocialPost post;
  final VoidCallback? onOpenPost;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 4 / 5,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onOpenPost,
              child: Hero(
                tag: 'post-${post.id}',
                child: Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: AppColors.sunken,
                    child: Center(
                      child: Icon(Icons.broken_image_outlined, size: 42),
                    ),
                  ),
                ),
              ),
            ),
            ...post.garments.map((garment) {
              const hitSize = 48.0;
              final left = (garment.x * constraints.maxWidth - hitSize / 2)
                  .clamp(0.0, constraints.maxWidth - hitSize)
                  .toDouble();
              final top = (garment.y * constraints.maxHeight - hitSize / 2)
                  .clamp(0.0, constraints.maxHeight - hitSize)
                  .toDouble();
              return Positioned(
                left: left,
                top: top,
                child: _GarmentHotspot(
                  key: Key('garment-hotspot-${post.id}-${garment.id}'),
                  label: garment.title,
                  heroTag: 'garment-${post.id}-${garment.id}',
                  onTap: () => showGarmentProductDialog(
                    context,
                    postId: post.id,
                    garment: garment,
                  ),
                ),
              );
            }),
            if (post.garments.isNotEmpty)
              Positioned(
                right: 12,
                top: 12,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xCC1E1D1B),
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '${post.garments.length} shoppable ${post.garments.length == 1 ? 'piece' : 'pieces'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _GarmentHotspot extends StatelessWidget {
  const _GarmentHotspot({
    super.key,
    required this.label,
    required this.heroTag,
    required this.onTap,
  });

  final String label;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Shop $label',
    child: Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          containedInkWell: true,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Hero(
                tag: heroTag,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xD91E1D1B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const SizedBox.square(
                    dimension: 34,
                    child: Icon(Icons.add, size: 21, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
