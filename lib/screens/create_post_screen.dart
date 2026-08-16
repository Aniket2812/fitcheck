import 'package:flutter/material.dart';

import '../components/garment_image.dart';
import '../models/model_photo.dart';
import '../models/social_post.dart';
import '../services/ingest_service.dart';
import '../services/model_photo_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({
    super.key,
    this.ingestLink,
    this.initialProductUrl,
    this.fetchModelPhotos = ModelPhotoService.fetchPhotos,
    this.checkYouCamConfigured = SocialService.youCamConfigured,
    this.generateLook = SocialService.createYouCamLook,
  });

  final IngestLink? ingestLink;
  final String? initialProductUrl;
  final FetchModelPhotos fetchModelPhotos;
  final CheckYouCamConfigured checkYouCamConfigured;
  final GenerateYouCamLook generateLook;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  final _productLink = TextEditingController();
  List<ModelPhoto> _modelPhotos = const [];
  ModelPhoto? _selectedModelPhoto;
  String? _youCamImageUrl;
  List<PostGarment> _garments = const [];
  int? _selectedGarment;
  bool _extracting = false;
  bool _publishing = false;
  bool _generating = false;
  bool _youCamConfigured = false;
  bool _loadingModelPhotos = true;
  String? _activeGenerationKey;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.checkYouCamConfigured().then((value) {
      if (!mounted) return;
      setState(() => _youCamConfigured = value);
      if (value) _generateWithYouCam();
    });
    _loadModelPhotos();
    final initialProductUrl = widget.initialProductUrl?.trim();
    if (initialProductUrl != null && initialProductUrl.isNotEmpty) {
      _productLink.text = initialProductUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) => _addGarment());
    }
  }

  Future<void> _loadModelPhotos() async {
    try {
      final photos = await widget.fetchModelPhotos();
      if (!mounted) return;
      final primary = photos.where((photo) => photo.isPrimary).firstOrNull;
      setState(() {
        _modelPhotos = photos;
        _selectedModelPhoto = primary ?? photos.firstOrNull;
      });
      _generateWithYouCam();
    } catch (error) {
      _setError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingModelPhotos = false);
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    _productLink.dispose();
    super.dispose();
  }

  void _selectModelPhoto(ModelPhoto photo) {
    setState(() {
      _selectedModelPhoto = photo;
      _youCamImageUrl = null;
      _error = null;
    });
    _generateWithYouCam();
  }

  Future<void> _addGarment() async {
    final link = _productLink.text.trim();
    if (link.isEmpty) return _setError('Paste a product link first.');
    setState(() {
      _extracting = true;
      _error = null;
    });
    try {
      final item = await (widget.ingestLink ?? IngestService.ingest)(link);
      if (item.pageUrl == null) {
        throw Exception('The product has no buying link.');
      }
      final garment = PostGarment(
        id: item.id,
        title: item.title,
        brand: item.brand,
        price: item.price,
        imageUrl: item.image,
        originalImageUrl: item.originalImage,
        buyUrl: item.pageUrl!,
        category: item.category,
        x: 0.5,
        y: 0.5,
      );
      if (!mounted) return;
      setState(() {
        _garments = [garment];
        _selectedGarment = 0;
        _youCamImageUrl = null;
        _productLink.clear();
      });
      _generateWithYouCam();
    } catch (error) {
      _setError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  void _placeTag(TapDownDetails details, Size size) {
    final selected = _selectedGarment;
    if (selected == null || selected >= _garments.length) return;
    final updated = [..._garments];
    updated[selected] = updated[selected].copyWith(
      x: (details.localPosition.dx / size.width).clamp(0.03, 0.97),
      y: (details.localPosition.dy / size.height).clamp(0.03, 0.97),
    );
    setState(() => _garments = updated);
  }

  Future<void> _generateWithYouCam() async {
    final modelPhoto = _selectedModelPhoto;
    final garment = _garments.firstOrNull;
    if (!_youCamConfigured || modelPhoto == null || garment == null) {
      return;
    }
    final generationKey = '${modelPhoto.id}:${garment.id}';
    if (_activeGenerationKey == generationKey) return;
    setState(() {
      _activeGenerationKey = generationKey;
      _generating = true;
      _youCamImageUrl = null;
      _error = null;
    });
    try {
      final url = await widget.generateLook(
        modelPhoto: modelPhoto,
        garment: garment,
      );
      if (mounted && _activeGenerationKey == generationKey) {
        setState(() => _youCamImageUrl = url);
      }
    } catch (error) {
      if (_activeGenerationKey == generationKey) {
        _setError(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && _activeGenerationKey == generationKey) {
        setState(() {
          _activeGenerationKey = null;
          _generating = false;
        });
      }
    }
  }

  Future<void> _publish() async {
    if (_selectedModelPhoto == null) {
      return _setError('Choose a saved full-body photo from My Photos.');
    }
    if (_garments.isEmpty) {
      return _setError('Add a fashion product link first.');
    }
    if (!_youCamConfigured) {
      return _setError('YouCam is not available. Try again later.');
    }
    if (_generating) {
      return _setError('Wait for YouCam to finish creating your preview.');
    }
    if (_youCamImageUrl == null) {
      _generateWithYouCam();
      return _setError('YouCam is creating your preview.');
    }
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final post = await SocialService.createPost(
        photo: null,
        photoUrl: _youCamImageUrl,
        caption: _caption.text,
        garments: _garments,
      );
      if (mounted) Navigator.pop(context, post);
    } catch (error) {
      _setError(error.toString().replaceFirst('Exception: ', ''));
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _setError(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialProductUrl == null ? 'New outfit' : 'Post shared item',
        ),
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            key: const Key('publish-post-button'),
            onPressed: _publishing ? null : _publish,
            child: _publishing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
          const SizedBox(width: AppSpacing.x2),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              const Text(
                'Add a fashion product',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.x1),
              const Text(
                'Paste a Myntra, Flipkart, Amazon, AJIO, or other fashion product link. We fetch the product image and buying details automatically.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x3),
              TextField(
                key: const Key('post-product-link-field'),
                controller: _productLink,
                enabled: !_extracting,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _addGarment(),
                decoration: InputDecoration(
                  labelText: 'Fashion product link',
                  hintText: 'Paste the retailer URL',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    key: const Key('tag-product-button'),
                    tooltip: 'Fetch product',
                    onPressed: _extracting ? null : _addGarment,
                    icon: _extracting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
              if (_garments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x3),
                SizedBox(
                  height: 92,
                  child: _GarmentChip(
                    garment: _garments.first,
                    number: 1,
                    selected: true,
                    onTap: () => setState(() => _selectedGarment = 0),
                    onRemove: () {
                      setState(() {
                        _garments = const [];
                        _selectedGarment = null;
                        _youCamImageUrl = null;
                        _activeGenerationKey = null;
                        _generating = false;
                      });
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.x4),
              _ModelPhotoPicker(
                loading: _loadingModelPhotos,
                photos: _modelPhotos,
                selected: _selectedModelPhoto,
                onSelect: _selectModelPhoto,
              ),
              const SizedBox(height: AppSpacing.x4),
              AspectRatio(
                aspectRatio: 4 / 5,
                child: _selectedModelPhoto == null
                    ? const _PhotoPlaceholder()
                    : _TaggablePhoto(
                        networkUrl:
                            _youCamImageUrl ?? _selectedModelPhoto?.imageUrl,
                        garments: _garments,
                        selected: _selectedGarment,
                        onSelect: (index) =>
                            setState(() => _selectedGarment = index),
                        onPlace: _placeTag,
                      ),
              ),
              if (_generating) ...[
                const SizedBox(height: AppSpacing.x3),
                const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.x2),
                const Text(
                  'YouCam is creating your try-on automatically…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ] else if (_youCamConfigured &&
                  _selectedModelPhoto != null &&
                  _garments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x4),
                OutlinedButton.icon(
                  key: const Key('youcam-generate-button'),
                  onPressed: _generateWithYouCam,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    _youCamImageUrl == null
                        ? 'Try YouCam again'
                        : 'Regenerate preview',
                  ),
                ),
              ] else if (!_youCamConfigured && _garments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x3),
                const Text(
                  'YouCam is currently unavailable, so this outfit cannot be posted yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
              if (_youCamImageUrl != null)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.x2),
                  child: Text(
                    'YouCam look ready. This generated image will be posted.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              const SizedBox(height: AppSpacing.x4),
              TextField(
                controller: _caption,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Caption',
                  hintText: 'Tell people about this fit…',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x3),
                  child: Text(
                    _error!,
                    key: const Key('create-post-error'),
                    style: const TextStyle(color: Color(0xFF8B5751)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelPhotoPicker extends StatelessWidget {
  const _ModelPhotoPicker({
    required this.loading,
    required this.photos,
    required this.selected,
    required this.onSelect,
  });

  final bool loading;
  final List<ModelPhoto> photos;
  final ModelPhoto? selected;
  final ValueChanged<ModelPhoto> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a saved full-body photo',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.x1),
        const Text(
          'YouCam will apply the linked product to this photo automatically.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.x2),
        if (loading)
          const SizedBox(
            height: 92,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (photos.isEmpty)
          Container(
            key: const Key('composer-no-saved-photos'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: AppColors.sunken,
              borderRadius: BorderRadius.circular(AppRadii.medium),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: const Row(
              children: [
                Icon(Icons.photo_library_outlined),
                SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    'No saved photos yet. Close this screen and add one from the My Photos tab.',
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x2),
              itemBuilder: (context, index) {
                final photo = photos[index];
                final isSelected = selected?.id == photo.id;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: 'Use ${photo.label}',
                  child: InkWell(
                    key: Key('composer-model-photo-${photo.id}'),
                    onTap: () => onSelect(photo),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    child: Container(
                      width: 88,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.borderDefault,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              photo.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(
                                  Icons.person,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Positioned(
                                right: 4,
                                top: 4,
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: AppColors.accent,
                                  child: Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('outfit-preview-placeholder'),
    decoration: BoxDecoration(
      color: AppColors.sunken,
      borderRadius: BorderRadius.circular(AppRadii.large),
      border: Border.all(color: AppColors.borderDefault),
    ),
    child: const Padding(
      padding: EdgeInsets.all(AppSpacing.x8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 42),
          SizedBox(height: AppSpacing.x3),
          Text(
            'Select a saved full-body photo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: AppSpacing.x1),
          Text(
            'Photos are added only from the My Photos tab.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _TaggablePhoto extends StatelessWidget {
  const _TaggablePhoto({
    required this.networkUrl,
    required this.garments,
    required this.selected,
    required this.onSelect,
    required this.onPlace,
  });

  final String? networkUrl;
  final List<PostGarment> garments;
  final int? selected;
  final ValueChanged<int> onSelect;
  final void Function(TapDownDetails, Size) onPlace;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadii.large),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: (details) => onPlace(details, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                networkUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.photo,
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: 54,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              ...garments.asMap().entries.map(
                (entry) => Positioned(
                  left: entry.value.x * size.width - 17,
                  top: entry.value.y * size.height - 17,
                  child: GestureDetector(
                    onTap: () => onSelect(entry.key),
                    child: _TagMarker(
                      number: entry.key + 1,
                      selected: selected == entry.key,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _TagMarker extends StatelessWidget {
  const _TagMarker({required this.number, required this.selected});
  final int number;
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    width: 34,
    height: 34,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: selected
          ? AppColors.accent
          : AppColors.raised.withValues(alpha: 0.92),
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.raised, width: 2),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
    ),
    child: Text(
      '$number',
      style: TextStyle(
        color: selected ? AppColors.textOnAccent : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _GarmentChip extends StatelessWidget {
  const _GarmentChip({
    required this.garment,
    required this.number,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });
  final PostGarment garment;
  final int number;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadii.medium),
    child: Container(
      width: 190,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.borderDefault,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: GarmentImage(
              source: garment.imageUrl,
              semanticLabel: garment.title,
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. ${garment.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (garment.brand != null)
                  Text(
                    garment.brand!,
                    maxLines: 1,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    ),
  );
}
