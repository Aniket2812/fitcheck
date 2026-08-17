import 'package:flutter/material.dart';

import '../models/social_post.dart';
import '../theme/app_theme.dart';
import 'garment_image.dart';
import 'garment_product_dialog.dart';

Future<void> showShoppablePiecesSheet(
  BuildContext context, {
  required SocialPost post,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.76,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHOP THE LOOK',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: AppSpacing.x1),
                    Text(
                      'Every piece in this fit',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ShoppablePiecesList(
            post: post,
            padding: const EdgeInsets.all(AppSpacing.x3),
          ),
        ),
      ],
    ),
  ),
);

class ShoppablePiecesList extends StatelessWidget {
  const ShoppablePiecesList({
    super.key,
    required this.post,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
    this.physics,
  });

  final SocialPost post;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: Key('shoppable-pieces-${post.id}'),
    padding: padding,
    shrinkWrap: shrinkWrap,
    physics: physics,
    itemCount: post.garments.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x2),
    itemBuilder: (context, index) =>
        _ShoppablePiece(postId: post.id, garment: post.garments[index]),
  );
}

class _ShoppablePiece extends StatelessWidget {
  const _ShoppablePiece({required this.postId, required this.garment});

  final String postId;
  final PostGarment garment;

  String get _retailer {
    final host = Uri.tryParse(
      garment.buyUrl,
    )?.host.replaceFirst(RegExp(r'^www\.'), '');
    return host?.isNotEmpty == true ? host! : 'Retailer link';
  }

  @override
  Widget build(BuildContext context) => Material(
    key: Key('shop-piece-$postId-${garment.id}'),
    color: AppColors.raised,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.borderDefault),
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () =>
          showGarmentProductDialog(context, postId: postId, garment: garment),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x2),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 66,
              padding: const EdgeInsets.all(AppSpacing.x1),
              decoration: BoxDecoration(
                color: AppColors.photo,
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: GarmentImage(
                source: garment.imageUrl,
                semanticLabel: garment.title,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    garment.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (garment.brand?.isNotEmpty == true) garment.brand!,
                      _retailer,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  if (garment.price?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      garment.price!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new, size: 18),
                SizedBox(height: 2),
                Text(
                  'BUY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
