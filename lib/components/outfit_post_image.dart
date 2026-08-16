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
            ...post.garments.map(
              (garment) => Positioned(
                left: garment.x * constraints.maxWidth - 18,
                top: garment.y * constraints.maxHeight - 18,
                child: Semantics(
                  button: true,
                  label: 'Shop ${garment.title}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showGarmentProductDialog(
                      context,
                      postId: post.id,
                      garment: garment,
                    ),
                    child: Hero(
                      tag: 'garment-${post.id}-${garment.id}',
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.raised.withValues(alpha: 0.94),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.textPrimary,
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x44000000), blurRadius: 10),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (post.garments.isNotEmpty)
              const Positioned(
                left: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xB31E1D1B),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      'Tap + to shop the fit',
                      style: TextStyle(
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
