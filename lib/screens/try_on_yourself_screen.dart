import 'package:flutter/material.dart';

import '../components/diagonal_processing_overlay.dart';
import '../models/model_photo.dart';
import '../models/social_post.dart';
import '../services/model_photo_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';

class TryOnYourselfScreen extends StatefulWidget {
  const TryOnYourselfScreen({
    super.key,
    required this.post,
    this.fetchModelPhotos = ModelPhotoService.fetchPhotos,
    this.generateOutfit = SocialService.createOutfitLook,
  });

  final SocialPost post;
  final FetchModelPhotos fetchModelPhotos;
  final GenerateOutfitLook generateOutfit;

  @override
  State<TryOnYourselfScreen> createState() => _TryOnYourselfScreenState();
}

class _TryOnYourselfScreenState extends State<TryOnYourselfScreen> {
  List<ModelPhoto> _photos = const [];
  ModelPhoto? _selected;
  String? _resultUrl;
  String? _error;
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await widget.fetchModelPhotos();
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _selected =
            photos.where((photo) => photo.isPrimary).firstOrNull ??
            photos.firstOrNull;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _generate() async {
    final photo = _selected;
    if (photo == null) return;
    if (widget.post.garments.isEmpty) {
      setState(() => _error = 'This post has no tagged items to try on.');
      return;
    }
    setState(() {
      _generating = true;
      _resultUrl = null;
      _error = null;
    });
    try {
      final result = await widget.generateOutfit(
        modelPhoto: photo,
        garments: widget.post.garments,
      );
      if (mounted) setState(() => _resultUrl = result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('try-on-yourself-screen'),
    backgroundColor: AppColors.canvas,
    appBar: AppBar(
      title: const Text('Try on yourself'),
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              const Text(
                'MAKE IT YOURS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                _resultUrl == null
                    ? 'See this complete fit on you.'
                    : 'Your version is ready.',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              AspectRatio(
                aspectRatio: 4 / 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _resultUrl ??
                            _selected?.imageUrl ??
                            widget.post.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.sunken,
                          child: Icon(Icons.person_outline, size: 52),
                        ),
                      ),
                      if (_generating)
                        const DiagonalProcessingOverlay(
                          key: Key('try-on-processing-animation'),
                          label: 'FITTING EVERY PIECE',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              if (_photos.isEmpty)
                Container(
                  key: const Key('try-on-no-photos'),
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: AppColors.sunken,
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: const Text(
                    'Add a full-body photo in My Photos first, then come back to try this fit.',
                    style: TextStyle(height: 1.4),
                  ),
                )
              else ...[
                const Text(
                  'Choose your full-body photo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.x2),
                SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.x2),
                    itemBuilder: (context, index) {
                      final photo = _photos[index];
                      final active = photo.id == _selected?.id;
                      return InkWell(
                        key: Key('try-on-photo-${photo.id}'),
                        onTap: _generating
                            ? null
                            : () => setState(() {
                                _selected = photo;
                                _resultUrl = null;
                              }),
                        child: Container(
                          width: 84,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                            border: Border.all(
                              color: active
                                  ? AppColors.accent
                                  : AppColors.borderDefault,
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.network(
                              photo.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: AppColors.sunken,
                                child: Icon(Icons.person_outline),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                FilledButton.icon(
                  key: const Key('run-try-on-button'),
                  onPressed: _generating ? null : _generate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    _generating
                        ? 'Trying on this fit…'
                        : _resultUrl == null
                        ? 'Try this look'
                        : 'Try again',
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x3),
                  child: Text(
                    _error!,
                    key: const Key('try-on-error'),
                    style: const TextStyle(color: Color(0xFF8B5751)),
                  ),
                ),
            ],
          ),
  );
}
