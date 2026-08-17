import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/social_post.dart';
import '../theme/app_theme.dart';
import 'garment_image.dart';

Future<void> showGarmentProductDialog(
  BuildContext context, {
  required String postId,
  required PostGarment garment,
}) {
  final retailerHost = Uri.tryParse(
    garment.buyUrl,
  )?.host.replaceFirst(RegExp(r'^www\.'), '');
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close garment',
    barrierColor: Colors.black.withValues(alpha: 0.68),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.42,
                      width: double.infinity,
                      child: Hero(
                        tag: 'garment-$postId-${garment.id}',
                        child: GarmentImage(
                          source: garment.imageUrl,
                          semanticLabel: garment.title,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    Text(
                      garment.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (garment.brand != null) ...[
                      const SizedBox(height: AppSpacing.x1),
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_outlined,
                            size: 17,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.x1),
                          Expanded(
                            child: Text(
                              retailerHost == null
                                  ? garment.brand!
                                  : '${garment.brand!} · $retailerHost',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (garment.price != null) ...[
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        garment.price!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.x4),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('buy-garment-button'),
                        onPressed: () async {
                          final uri = Uri.tryParse(garment.buyUrl);
                          if (uri == null ||
                              !await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              )) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not open this buying link.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('View product'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    const Center(
                      child: Text(
                        'Opens the retailer’s product page',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
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
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        ),
  );
}
