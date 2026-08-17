import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared persistent image cache for every remote photo in the app.
///
/// `memCacheWidth` keeps decoded images appropriately sized in memory while
/// the original response remains available in the on-device disk cache.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.placeholder,
    this.error,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  final Widget? placeholder;
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return error ?? _fallback;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      memCacheWidth: cacheWidth,
      maxWidthDiskCache: cacheWidth?.clamp(480, 1600).toInt(),
      fadeInDuration: const Duration(milliseconds: 140),
      fadeOutDuration: const Duration(milliseconds: 80),
      useOldImageOnUrlChange: true,
      placeholder: (_, _) => placeholder ?? _fallback,
      errorWidget: (_, _, _) => error ?? _fallback,
    );
  }

  static const Widget _fallback = ColoredBox(color: AppColors.sunken);
}
