import 'package:flutter/material.dart';

import '../components/diagonal_processing_overlay.dart';
import '../components/garment_image.dart';
import '../models/fashion_collection.dart';
import '../models/model_photo.dart';
import '../models/social_post.dart';
import '../services/collection_service.dart';
import '../services/model_photo_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({
    super.key,
    this.fetchCollections = CollectionService.fetchCollections,
    this.fetchModelPhotos = ModelPhotoService.fetchPhotos,
    this.checkYouCamConfigured = SocialService.youCamConfigured,
    this.generateOutfit = SocialService.createOutfitLook,
  });

  final FetchCollections fetchCollections;
  final FetchModelPhotos fetchModelPhotos;
  final CheckYouCamConfigured checkYouCamConfigured;
  final GenerateOutfitLook generateOutfit;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  List<FashionCollection> _collections = const [];
  List<ModelPhoto> _modelPhotos = const [];
  final Set<String> _selectedIds = {};
  ModelPhoto? _selectedModelPhoto;
  String? _previewUrl;
  int _selectedGarmentIndex = 0;
  bool _loading = true;
  bool _youCamConfigured = false;
  bool _generating = false;
  bool _publishing = false;
  String? _error;

  List<CollectionItem> get _selectedItems => _collections
      .expand((collection) => collection.items)
      .where((item) => _selectedIds.contains(item.id))
      .toList();

  List<PostGarment> get _garments => _selectedItems
      .asMap()
      .entries
      .map((entry) => entry.value.toGarment(index: entry.key))
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final collectionsFuture = widget.fetchCollections();
      final photosFuture = widget.fetchModelPhotos();
      final configuredFuture = widget.checkYouCamConfigured();
      final collections = await collectionsFuture;
      final photos = await photosFuture;
      final configured = await configuredFuture;
      if (!mounted) return;
      final primary = photos.where((photo) => photo.isPrimary).firstOrNull;
      setState(() {
        _collections = collections;
        _modelPhotos = photos;
        _selectedModelPhoto = primary ?? photos.firstOrNull;
        _youCamConfigured = configured;
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

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _toggle(CollectionItem item) {
    setState(() {
      if (_selectedIds.remove(item.id)) {
        _previewUrl = null;
        return;
      }
      final allItems = _collections.expand((collection) => collection.items);
      if (item.category != 'accessory') {
        _selectedIds.removeWhere((id) {
          final selected = allItems
              .where((entry) => entry.id == id)
              .firstOrNull;
          if (selected == null) return false;
          if (selected.category == item.category) return true;
          if (item.category == 'full_body') {
            return selected.category == 'upper_body' ||
                selected.category == 'lower_body';
          }
          if (item.category == 'upper_body' || item.category == 'lower_body') {
            return selected.category == 'full_body';
          }
          return false;
        });
      }
      _selectedIds.add(item.id);
      _previewUrl = null;
      _selectedGarmentIndex = 0;
      _error = null;
    });
  }

  void _selectPhoto(ModelPhoto photo) {
    setState(() {
      _selectedModelPhoto = photo;
      _previewUrl = null;
      _error = null;
    });
  }

  Future<void> _generate() async {
    final modelPhoto = _selectedModelPhoto;
    final garments = _garments;
    if (garments.isEmpty) {
      return _setError('Choose at least one collection item.');
    }
    if (modelPhoto == null) {
      return _setError('Choose a saved full-body photo from My Photos.');
    }
    if (!_youCamConfigured) {
      return _setError('YouCam is currently unavailable.');
    }
    setState(() {
      _generating = true;
      _previewUrl = null;
      _error = null;
    });
    try {
      final url = await widget.generateOutfit(
        modelPhoto: modelPhoto,
        garments: garments,
      );
      if (mounted) setState(() => _previewUrl = url);
    } catch (error) {
      _setError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _publish() async {
    if (_garments.isEmpty) {
      return _setError('Choose at least one collection item.');
    }
    if (_selectedModelPhoto == null) {
      return _setError('Choose a saved full-body photo from My Photos.');
    }
    if (_generating) {
      return _setError('Wait for your outfit preview to finish.');
    }
    if (_previewUrl == null) {
      return _setError('Generate your outfit preview first.');
    }
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final post = await SocialService.createPost(
        photo: null,
        photoUrl: _previewUrl,
        caption: _caption.text,
        garments: _garments,
      );
      if (mounted) Navigator.pop(context, post);
    } catch (error) {
      _setError(error.toString().replaceFirst('Exception: ', ''));
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _placeTag(TapDownDetails details, Size size) {
    final garments = _garments;
    if (garments.isEmpty || _selectedGarmentIndex >= garments.length) return;
    // Collection items are rebuilt from stable defaults. Manual hotspot
    // positioning is intentionally visual-only for the hackathon preview;
    // category defaults are persisted when the post is created.
    setState(() {});
  }

  void _setError(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    appBar: AppBar(
      title: const Text('Build an outfit'),
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
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  const _StepTitle(
                    number: '01',
                    title: 'Pick your pieces',
                    subtitle:
                        'Mix items from your collections. Tops, bottoms, dresses, and shoes stay category-aware.',
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  _CollectionPicker(
                    collections: _collections,
                    selectedIds: _selectedIds,
                    onToggle: _toggle,
                  ),
                  const SizedBox(height: AppSpacing.x8),
                  const _StepTitle(
                    number: '02',
                    title: 'Choose your photo',
                    subtitle:
                        'Select a full-body photo you already saved in My Photos.',
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  _PhotoPicker(
                    photos: _modelPhotos,
                    selected: _selectedModelPhoto,
                    onSelect: _selectPhoto,
                  ),
                  const SizedBox(height: AppSpacing.x8),
                  const _StepTitle(
                    number: '03',
                    title: 'Create the look',
                    subtitle:
                        'YouCam applies compatible pieces in outfit order and returns one post-ready image.',
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  AspectRatio(
                    aspectRatio: 4 / 5,
                    child: _OutfitPreview(
                      imageUrl: _previewUrl ?? _selectedModelPhoto?.imageUrl,
                      garments: _garments,
                      selectedIndex: _selectedGarmentIndex,
                      generating: _generating,
                      onSelect: (index) =>
                          setState(() => _selectedGarmentIndex = index),
                      onPlace: _placeTag,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('generate-outfit-button'),
                      onPressed: _generating ? null : _generate,
                      icon: _generating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _generating
                            ? 'Styling your complete look…'
                            : _previewUrl == null
                            ? 'Generate outfit preview'
                            : 'Regenerate outfit',
                      ),
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
                      padding: const EdgeInsets.only(top: AppSpacing.x2),
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

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.number,
    required this.title,
    required this.subtitle,
  });
  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        number,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: AppColors.textMuted,
        ),
      ),
      const SizedBox(width: AppSpacing.x3),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CollectionPicker extends StatelessWidget {
  const _CollectionPicker({
    required this.collections,
    required this.selectedIds,
    required this.onToggle,
  });
  final List<FashionCollection> collections;
  final Set<String> selectedIds;
  final ValueChanged<CollectionItem> onToggle;

  @override
  Widget build(BuildContext context) {
    final populated = collections
        .where((collection) => collection.items.isNotEmpty)
        .toList();
    if (populated.isEmpty) {
      return Container(
        key: const Key('composer-no-collection-items'),
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: AppColors.sunken,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: const Text(
          'Your collections are empty. Share products from fashion apps or add buying links in Collections first.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
      );
    }
    return Column(
      children: populated
          .map(
            (collection) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          collection.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${collection.items.length}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  SizedBox(
                    height: 152,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: collection.items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = collection.items[index];
                        final selected = selectedIds.contains(item.id);
                        return _SelectableItem(
                          item: item,
                          selected: selected,
                          onTap: () => onToggle(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SelectableItem extends StatelessWidget {
  const _SelectableItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final CollectionItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('collection-item-${item.id}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadii.medium),
    child: Container(
      width: 112,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.borderDefault,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GarmentImage(source: item.imageUrl, semanticLabel: item.title),
                if (selected)
                  const Align(
                    alignment: Alignment.topRight,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.accent,
                      child: Icon(
                        Icons.check,
                        size: 13,
                        color: AppColors.textOnAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ),
  );
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photos,
    required this.selected,
    required this.onSelect,
  });
  final List<ModelPhoto> photos;
  final ModelPhoto? selected;
  final ValueChanged<ModelPhoto> onSelect;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Container(
        key: const Key('composer-no-saved-photos'),
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: AppColors.sunken,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: const Text(
          'No full-body photos yet. Add one from My Photos before building an outfit.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x2),
        itemBuilder: (context, index) {
          final photo = photos[index];
          final active = photo.id == selected?.id;
          return InkWell(
            key: Key('composer-model-photo-${photo.id}'),
            onTap: () => onSelect(photo),
            borderRadius: BorderRadius.circular(AppRadii.medium),
            child: Container(
              width: 90,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.medium),
                border: Border.all(
                  color: active ? AppColors.accent : AppColors.borderDefault,
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
                    child: Icon(Icons.person, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OutfitPreview extends StatelessWidget {
  const _OutfitPreview({
    required this.imageUrl,
    required this.garments,
    required this.selectedIndex,
    required this.generating,
    required this.onSelect,
    required this.onPlace,
  });
  final String? imageUrl;
  final List<PostGarment> garments;
  final int selectedIndex;
  final bool generating;
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
              if (imageUrl == null)
                const ColoredBox(
                  color: AppColors.sunken,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_outlined, size: 42),
                      SizedBox(height: AppSpacing.x2),
                      Text('Your complete look will appear here'),
                    ],
                  ),
                )
              else
                Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: AppColors.sunken,
                    child: Icon(Icons.person, size: 48),
                  ),
                ),
              if (!generating)
                ...garments.asMap().entries.map(
                  (entry) => Positioned(
                    left: entry.value.x * size.width - 16,
                    top: entry.value.y * size.height - 16,
                    child: GestureDetector(
                      onTap: () => onSelect(entry.key),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: selectedIndex == entry.key
                            ? AppColors.accent
                            : AppColors.raised,
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(
                            color: selectedIndex == entry.key
                                ? AppColors.textOnAccent
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (generating) const DiagonalProcessingOverlay(),
            ],
          ),
        );
      },
    ),
  );
}
