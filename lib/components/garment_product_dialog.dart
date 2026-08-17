import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/social_post.dart';
import '../theme/app_theme.dart';
import 'garment_image.dart';

Future<void> showGarmentProductDialog(
  BuildContext context, {
  required String postId,
  required PostGarment garment,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close product gallery',
  barrierColor: Colors.black.withValues(alpha: 0.7),
  transitionDuration: const Duration(milliseconds: 260),
  pageBuilder: (context, animation, secondaryAnimation) =>
      _GarmentProductDialog(postId: postId, garment: garment),
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
);

class _GarmentProductDialog extends StatefulWidget {
  const _GarmentProductDialog({required this.postId, required this.garment});

  final String postId;
  final PostGarment garment;

  @override
  State<_GarmentProductDialog> createState() => _GarmentProductDialogState();
}

class _GarmentProductDialogState extends State<_GarmentProductDialog> {
  final PageController _controller = PageController();
  int _page = 0;

  PostGarment get garment => widget.garment;

  List<String> get _gallery {
    final images = garment.productImageUrls
        .where((source) => source.isNotEmpty)
        .take(5)
        .toList();
    if (images.isEmpty && garment.originalImageUrl?.isNotEmpty == true) {
      images.add(garment.originalImageUrl!);
    }
    if (images.isEmpty) images.add(garment.imageUrl);
    while (images.length < 4) {
      images.add(images.last);
    }
    return images;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openProduct() async {
    final uri = Uri.tryParse(garment.buyUrl);
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('That shopping link won’t open right now.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gallery = _gallery;
    final retailerHost = Uri.tryParse(
      garment.buyUrl,
    )?.host.replaceFirst(RegExp(r'^www\.'), '');
    final height = (MediaQuery.sizeOf(context).height * 0.88)
        .clamp(500.0, 780.0)
        .toDouble();

    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x3),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                height: height,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 10, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'THE PIECE, UP CLOSE',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${gallery.length} product views',
                                  key: const Key('product-gallery-count'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
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
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        decoration: BoxDecoration(
                          color: AppColors.photo,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Hero(
                          tag: 'garment-${widget.postId}-${garment.id}',
                          child: PageView.builder(
                            key: const Key('product-gallery-page-view'),
                            controller: _controller,
                            itemCount: gallery.length,
                            onPageChanged: (page) =>
                                setState(() => _page = page),
                            itemBuilder: (context, index) =>
                                _ProductGalleryImage(
                                  source: gallery[index],
                                  title: garment.title,
                                  index: index,
                                  useDetailCrop:
                                      index > 0 && gallery.toSet().length == 1,
                                ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        key: const Key('product-gallery-thumbnails'),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x3,
                          vertical: AppSpacing.x2,
                        ),
                        itemCount: gallery.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.x2),
                        itemBuilder: (context, index) => GestureDetector(
                          key: Key('product-gallery-thumbnail-$index'),
                          onTap: () => _controller.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 52,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.photo,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: index == _page
                                    ? AppColors.textPrimary
                                    : AppColors.borderDefault,
                                width: index == _page ? 1.5 : 1,
                              ),
                            ),
                            child: GarmentImage(
                              source: gallery[index],
                              semanticLabel:
                                  '${garment.title}, thumbnail ${index + 1}',
                              cacheWidth: 140,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            garment.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x1),
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_outlined,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.x1),
                              Expanded(
                                child: Text(
                                  [
                                    garment.brand,
                                    retailerHost,
                                  ].whereType<String>().join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (garment.price != null)
                                Text(
                                  garment.price!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.x3),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const Key('buy-garment-button'),
                              onPressed: _openProduct,
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Shop this exact piece'),
                            ),
                          ),
                        ],
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

class _ProductGalleryImage extends StatelessWidget {
  const _ProductGalleryImage({
    required this.source,
    required this.title,
    required this.index,
    required this.useDetailCrop,
  });

  final String source;
  final String title;
  final int index;
  final bool useDetailCrop;

  static const _detailAlignments = [
    Alignment.center,
    Alignment.topCenter,
    Alignment.centerLeft,
    Alignment.bottomRight,
    Alignment.centerRight,
  ];

  @override
  Widget build(BuildContext context) {
    final image = GarmentImage(
      key: Key('product-gallery-image-$index'),
      source: source,
      semanticLabel: '$title, product image ${index + 1}',
      cacheWidth: 1100,
      alignment: _detailAlignments[index % _detailAlignments.length],
    );
    if (!useDetailCrop) {
      return Padding(padding: const EdgeInsets.all(16), child: image);
    }
    return ClipRect(
      child: Transform.scale(
        scale: 1.18 + (index % 3) * 0.12,
        alignment: _detailAlignments[index % _detailAlignments.length],
        child: Padding(padding: const EdgeInsets.all(16), child: image),
      ),
    );
  }
}
