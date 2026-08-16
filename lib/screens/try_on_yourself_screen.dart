import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../components/diagonal_processing_overlay.dart';
import '../models/model_photo.dart';
import '../models/social_post.dart';
import '../services/model_photo_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';

typedef PickFullBodyPhoto = Future<XFile?> Function(ImageSource source);

Future<XFile?> _pickFullBodyPhoto(ImageSource source) =>
    ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );

class TryOnYourselfScreen extends StatefulWidget {
  const TryOnYourselfScreen({
    super.key,
    required this.post,
    this.fetchModelPhotos = ModelPhotoService.fetchPhotos,
    this.uploadModelPhoto = ModelPhotoService.upload,
    this.pickPhoto = _pickFullBodyPhoto,
    this.generateOutfit = SocialService.createOutfitLook,
  });

  final SocialPost post;
  final FetchModelPhotos fetchModelPhotos;
  final UploadModelPhoto uploadModelPhoto;
  final PickFullBodyPhoto pickPhoto;
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
  bool _uploading = false;
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
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('try-on-gallery-option'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Pick a clear full-body photo'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              key: const Key('try-on-camera-option'),
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a new photo'),
              subtitle: const Text(
                'Stand straight with your full body visible',
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickAndUpload(source);
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picked = await widget.pickPhoto(source);
      if (picked == null || !mounted) return;
      setState(() {
        _uploading = true;
        _error = null;
      });
      final photo = await widget.uploadModelPhoto(picked);
      if (!mounted) return;
      setState(() {
        _photos = [photo, ..._photos.where((item) => item.id != photo.id)];
        _selected = photo;
        _resultUrl = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('ClientConnection') ||
        message.contains('SocketException') ||
        message.contains('TimeoutException')) {
      return 'Could not reach your photo library. Keep the backend running and reconnect wireless debugging, then try again.';
    }
    return message;
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
        setState(() => _error = _friendlyError(error));
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
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 28),
            children: [
              const Text(
                'MAKE IT YOURS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                _resultUrl == null
                    ? 'See this complete fit on you.'
                    : 'Your version is ready.',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
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
              const SizedBox(height: AppSpacing.x3),
              if (_photos.isEmpty)
                Container(
                  key: const Key('try-on-no-photos'),
                  padding: const EdgeInsets.all(AppSpacing.x3),
                  decoration: BoxDecoration(
                    color: AppColors.sunken,
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add a full-body photo now',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      const Text(
                        'Use it immediately for this fit. It will also be saved in My Photos for future try-ons.',
                        style: TextStyle(height: 1.4),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('try-on-add-photo-button'),
                          onPressed: _uploading ? null : _chooseSource,
                          icon: _uploading
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_a_photo_outlined),
                          label: Text(
                            _uploading ? 'Saving photo…' : 'Add your photo',
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choose your full-body photo',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('try-on-add-another-photo-button'),
                      onPressed: _uploading || _generating
                          ? null
                          : _chooseSource,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 17),
                      label: const Text('Add new'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                SizedBox(
                  height: 92,
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
                          width: 70,
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
                const SizedBox(height: AppSpacing.x2),
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
