import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GarmentImage extends StatelessWidget {
  const GarmentImage({
    super.key,
    required this.source,
    this.semanticLabel,
    this.cacheWidth,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final String source;
  final String? semanticLabel;
  final int? cacheWidth;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: image),
    );
  }

  Widget _buildImage() {
    if (source.startsWith('data:image/')) {
      try {
        final comma = source.indexOf(',');
        final bytes = base64Decode(source.substring(comma + 1));
        return Image.memory(
          Uint8List.fromList(bytes),
          fit: fit,
          alignment: alignment,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: _errorBuilder,
        );
      } catch (_) {
        return _placeholder();
      }
    }

    return Image.network(
      source,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: _errorBuilder,
    );
  }

  Widget _errorBuilder(BuildContext context, Object error, StackTrace? stack) {
    return _placeholder();
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(
        Icons.checkroom_outlined,
        color: AppColors.textMuted,
        size: 44,
      ),
    );
  }
}
