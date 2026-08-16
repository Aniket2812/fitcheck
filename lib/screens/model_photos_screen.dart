import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../components/screen.dart';
import '../models/model_photo.dart';
import '../services/model_photo_service.dart';
import '../theme/app_theme.dart';

class ModelPhotosScreen extends StatefulWidget {
  const ModelPhotosScreen({
    super.key,
    required this.onSearch,
    required this.onProfile,
    this.profileName = 'YouCam Creator',
    this.profileAvatarUrl,
    this.fetchPhotos = ModelPhotoService.fetchPhotos,
    this.uploadPhoto = ModelPhotoService.upload,
    this.deletePhoto = ModelPhotoService.delete,
    this.setPrimaryPhoto = ModelPhotoService.setPrimary,
  });

  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final String profileName;
  final String? profileAvatarUrl;
  final FetchModelPhotos fetchPhotos;
  final UploadModelPhoto uploadPhoto;
  final DeleteModelPhoto deletePhoto;
  final SetPrimaryModelPhoto setPrimaryPhoto;

  @override
  State<ModelPhotosScreen> createState() => _ModelPhotosScreenState();
}

class _ModelPhotosScreenState extends State<ModelPhotosScreen> {
  final _picker = ImagePicker();
  List<ModelPhoto> _photos = const [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final photos = await widget.fetchPhotos();
      if (mounted) setState(() => _photos = photos);
    } catch (error) {
      _setError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
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
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a full-body photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickAndUpload(source);
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final photo = await widget.uploadPhoto(picked);
      if (mounted) setState(() => _photos = [..._photos, photo]);
    } catch (error) {
      _setError(error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _makePrimary(ModelPhoto selected) async {
    try {
      await widget.setPrimaryPhoto(selected.id);
      if (!mounted) return;
      setState(() {
        _photos = _photos
            .map((photo) => photo.copyWith(isPrimary: photo.id == selected.id))
            .toList();
      });
    } catch (error) {
      _setError(error);
    }
  }

  Future<void> _delete(ModelPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this photo?'),
        content: const Text(
          'Existing posts stay unchanged, but this photo will no longer be available for new try-ons.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.deletePhoto(photo.id);
      if (!mounted) return;
      setState(() {
        final remaining = _photos.where((item) => item.id != photo.id).toList();
        if (photo.isPrimary && remaining.isNotEmpty) {
          remaining[0] = remaining[0].copyWith(isPrimary: true);
        }
        _photos = remaining;
      });
    } catch (error) {
      _setError(error);
    }
  }

  void _setError(Object error) {
    if (!mounted) return;
    setState(() {
      _error = error.toString().replaceFirst('Exception: ', '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompeteScreen(
      onSearch: widget.onSearch,
      onProfile: widget.onProfile,
      profileName: widget.profileName,
      profileAvatarUrl: widget.profileAvatarUrl,
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My full-body photos',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: AppSpacing.x1),
                          Text(
                            'Upload once, then reuse any photo for a virtual try-on.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    FilledButton.icon(
                      key: const Key('add-model-photo-button'),
                      onPressed: _uploading ? null : _chooseSource,
                      icon: _uploading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFF8B5751)),
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_photos.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyPhotos(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    final photo = _photos[index];
                    return _PhotoCard(
                      photo: photo,
                      onPrimary: () => _makePrimary(photo),
                      onDelete: () => _delete(photo),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPhotos extends StatelessWidget {
  const _EmptyPhotos();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, 92),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.accessibility_new, size: 46, color: AppColors.textMuted),
          SizedBox(height: AppSpacing.x3),
          Text(
            'Add your first full-body photo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: AppSpacing.x2),
          Text(
            'Use a clear, front-facing photo with your full outfit area visible.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    ),
  );
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.onPrimary,
    required this.onDelete,
  });

  final ModelPhoto photo;
  final VoidCallback onPrimary;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadii.large),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: AppColors.photo,
          child: Image.network(
            photo.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.person, size: 42, color: AppColors.textMuted),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xAA000000)],
              stops: [0.55, 1],
            ),
          ),
        ),
        if (photo.isPrimary)
          const Positioned(
            left: 10,
            top: 10,
            child: Chip(
              avatar: Icon(Icons.star, size: 16),
              label: Text('Default'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        Positioned(
          right: 4,
          top: 4,
          child: PopupMenuButton<String>(
            color: AppColors.raised,
            onSelected: (value) {
              if (value == 'primary') onPrimary();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              if (!photo.isPrimary)
                const PopupMenuItem(
                  value: 'primary',
                  child: Text('Make default'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Remove')),
            ],
            icon: const Icon(Icons.more_horiz, color: Colors.white),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Text(
            photo.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
