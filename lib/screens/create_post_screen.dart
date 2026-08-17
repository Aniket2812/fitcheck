import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../components/diagonal_processing_overlay.dart';
import '../components/garment_image.dart';
import '../models/fashion_collection.dart';
import '../models/model_photo.dart';
import '../models/social_post.dart';
import '../services/collection_service.dart';
import '../services/ingest_service.dart';
import '../services/model_photo_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';

typedef PickComposerPhoto = Future<XFile?> Function(ImageSource source);

Future<XFile?> _pickComposerPhoto(ImageSource source) =>
    ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({
    super.key,
    this.fetchCollections = CollectionService.fetchCollections,
    this.createCollection = CollectionService.createCollection,
    this.ingestLink = IngestService.ingest,
    this.saveCollectionItem = CollectionService.addItem,
    this.fetchModelPhotos = ModelPhotoService.fetchPhotos,
    this.uploadModelPhoto = ModelPhotoService.upload,
    this.pickPhoto = _pickComposerPhoto,
    this.checkYouCamConfigured = SocialService.youCamConfigured,
    this.generateOutfit = SocialService.createOutfitLook,
  });

  final FetchCollections fetchCollections;
  final CreateFashionCollection createCollection;
  final IngestLink ingestLink;
  final SaveCollectionItem saveCollectionItem;
  final FetchModelPhotos fetchModelPhotos;
  final UploadModelPhoto uploadModelPhoto;
  final PickComposerPhoto pickPhoto;
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
  bool _addingProduct = false;
  bool _uploadingPhoto = false;
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
    final collectionsFuture = widget.fetchCollections();
    final photosFuture = widget.fetchModelPhotos();
    final configuredFuture = widget.checkYouCamConfigured();
    List<FashionCollection> collections = const [];
    List<ModelPhoto> photos = const [];
    var configured = false;
    String? loadError;
    try {
      collections = await collectionsFuture;
    } catch (error) {
      loadError = _friendlyError(error);
    }
    try {
      photos = await photosFuture;
    } catch (error) {
      loadError ??= _friendlyError(error);
    }
    try {
      configured = await configuredFuture;
    } catch (_) {
      configured = false;
    }
    if (!mounted) return;
    final primary = photos.where((photo) => photo.isPrimary).firstOrNull;
    setState(() {
      _collections = collections;
      _modelPhotos = photos;
      _selectedModelPhoto ??= primary ?? photos.firstOrNull;
      _youCamConfigured = configured;
      _loading = false;
      _error = loadError;
    });
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('ClientConnection') ||
        message.contains('SocketException') ||
        message.contains('TimeoutException')) {
      return 'Some studio data could not load. Keep the backend running and reconnect wireless debugging, then refresh.';
    }
    return message;
  }

  Future<FashionCollection?> _createCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a collection'),
        content: TextField(
          key: const Key('composer-new-collection-name'),
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Collection name',
            hintText: 'Date night layers',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('composer-create-collection-submit'),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return null;
    try {
      final collection = await widget.createCollection(name);
      if (mounted) {
        setState(() {
          _collections = [..._collections, collection];
          _error = null;
        });
      }
      return collection;
    } catch (error) {
      _setError(_friendlyError(error));
      return null;
    }
  }

  Future<FashionCollection?> _chooseCollection() async {
    if (_collections.isEmpty) return _createCollection();
    return showModalBottomSheet<FashionCollection>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text(
              'Save product into',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.x2),
            ..._collections.map(
              (collection) => ListTile(
                key: Key('composer-target-${collection.id}'),
                leading: const Icon(Icons.folder_outlined),
                title: Text(collection.name),
                subtitle: Text('${collection.items.length} items'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.pop(sheetContext, collection),
              ),
            ),
            const Divider(),
            ListTile(
              key: const Key('composer-new-collection-from-picker'),
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Create a new collection'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _createCollection();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProduct() async {
    final collection = await _chooseCollection();
    if (collection == null || !mounted) return;
    final controller = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add to ${collection.name}'),
        content: TextField(
          key: const Key('composer-product-link'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Fashion product link',
            hintText: 'Paste a Myntra, AJIO, Amazon or Flipkart URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('composer-fetch-product-submit'),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Fetch item'),
          ),
        ],
      ),
    );
    if (link == null || link.isEmpty) return;
    setState(() {
      _addingProduct = true;
      _error = null;
    });
    try {
      final product = await widget.ingestLink(link);
      final saved = await widget.saveCollectionItem(collection.id, product);
      final refreshed = await widget.fetchCollections();
      if (!mounted) return;
      setState(() {
        _collections = refreshed;
        _selectedIds.add(saved.id);
        _previewUrl = null;
      });
    } catch (error) {
      _setError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _addingProduct = false);
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('composer-gallery-option'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              key: const Key('composer-camera-option'),
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a full-body photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickAndUploadPhoto(source);
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picked = await widget.pickPhoto(source);
      if (picked == null || !mounted) return;
      setState(() {
        _uploadingPhoto = true;
        _error = null;
      });
      final photo = await widget.uploadModelPhoto(picked);
      if (!mounted) return;
      setState(() {
        _modelPhotos = [
          photo,
          ..._modelPhotos.where((item) => item.id != photo.id),
        ];
        _selectedModelPhoto = photo;
        _previewUrl = null;
      });
    } catch (error) {
      _setError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
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
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  key: const Key('outfit-studio'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 28),
                  children: [
                    _StudioProgress(
                      hasPieces: _selectedIds.isNotEmpty,
                      hasPhoto: _selectedModelPhoto != null,
                      hasPreview: _previewUrl != null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    const _StepTitle(
                      number: '01',
                      title: 'Pick your pieces',
                      subtitle:
                          'Mix items from your collections. Tops, bottoms, dresses, and shoes stay category-aware.',
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Wrap(
                      spacing: AppSpacing.x2,
                      runSpacing: AppSpacing.x2,
                      children: [
                        FilledButton.icon(
                          key: const Key('composer-add-product-button'),
                          onPressed: _addingProduct ? null : _addProduct,
                          icon: _addingProduct
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_link, size: 18),
                          label: Text(
                            _addingProduct
                                ? 'Fetching product…'
                                : 'Add product link',
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const Key('composer-create-collection-button'),
                          onPressed: _addingProduct ? null : _createCollection,
                          icon: const Icon(
                            Icons.create_new_folder_outlined,
                            size: 18,
                          ),
                          label: const Text('New collection'),
                        ),
                        IconButton.outlined(
                          key: const Key('composer-refresh-button'),
                          tooltip: 'Refresh studio data',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    _CollectionPicker(
                      collections: _collections,
                      selectedIds: _selectedIds,
                      onToggle: _toggle,
                    ),
                    if (_selectedItems.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.x2),
                      _SelectedPieces(items: _selectedItems, onRemove: _toggle),
                    ],
                    const SizedBox(height: AppSpacing.x6),
                    const _StepTitle(
                      number: '02',
                      title: 'Choose your photo',
                      subtitle:
                          'Select a full-body photo you already saved in My Photos.',
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('composer-add-photo-button'),
                        onPressed: _uploadingPhoto ? null : _choosePhotoSource,
                        icon: _uploadingPhoto
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: Text(
                          _uploadingPhoto
                              ? 'Saving photo…'
                              : _modelPhotos.isEmpty
                              ? 'Add full-body photo'
                              : 'Add another photo',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    _PhotoPicker(
                      photos: _modelPhotos,
                      selected: _selectedModelPhoto,
                      onSelect: _selectPhoto,
                    ),
                    const SizedBox(height: AppSpacing.x6),
                    const _StepTitle(
                      number: '03',
                      title: 'Create the look',
                      subtitle:
                          'YouCam applies compatible pieces in outfit order and returns one post-ready image.',
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('generate-outfit-button'),
                        onPressed: _generating ? null : _generate,
                        icon: _generating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                    if (_selectedIds.isEmpty || _selectedModelPhoto == null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.x2),
                        child: Text(
                          _selectedIds.isEmpty
                              ? 'Choose at least one product to continue.'
                              : 'Choose or add a full-body photo to continue.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.x2),
                    AspectRatio(
                      aspectRatio: 4 / 5,
                      child: _OutfitPreview(
                        imageUrl: _previewUrl,
                        garments: _garments,
                        selectedIndex: _selectedGarmentIndex,
                        generating: _generating,
                        onSelect: (index) =>
                            setState(() => _selectedGarmentIndex = index),
                        onPlace: _placeTag,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
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
          ),
  );
}

class _StudioProgress extends StatelessWidget {
  const _StudioProgress({
    required this.hasPieces,
    required this.hasPhoto,
    required this.hasPreview,
  });

  final bool hasPieces;
  final bool hasPhoto;
  final bool hasPreview;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.x3,
      vertical: AppSpacing.x2,
    ),
    decoration: BoxDecoration(
      color: AppColors.raised,
      borderRadius: BorderRadius.circular(AppRadii.large),
    ),
    child: Row(
      children: [
        _ProgressNode(label: 'Pieces', complete: hasPieces),
        const Expanded(child: Divider()),
        _ProgressNode(label: 'Photo', complete: hasPhoto),
        const Expanded(child: Divider()),
        _ProgressNode(label: 'Preview', complete: hasPreview),
      ],
    ),
  );
}

class _ProgressNode extends StatelessWidget {
  const _ProgressNode({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedContainer(
        duration: AppMotion.standard,
        curve: AppMotion.curve,
        width: 27,
        height: 27,
        decoration: BoxDecoration(
          color: complete ? AppColors.fresh : AppColors.sunken,
          shape: BoxShape.circle,
          border: Border.all(
            color: complete ? AppColors.fresh : AppColors.borderStrong,
          ),
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.quick,
          child: Icon(
            complete ? Icons.check_rounded : Icons.circle_outlined,
            key: ValueKey(complete),
            size: 14,
            color: complete ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.x1),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class _SelectedPieces extends StatelessWidget {
  const _SelectedPieces({required this.items, required this.onRemove});

  final List<CollectionItem> items;
  final ValueChanged<CollectionItem> onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.x3),
    decoration: BoxDecoration(
      color: AppColors.sunken,
      borderRadius: BorderRadius.circular(AppRadii.large),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${items.length} ${items.length == 1 ? 'piece' : 'pieces'} in this look',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.x2),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x1,
          children: items
              .map(
                (item) => InputChip(
                  key: Key('selected-piece-${item.id}'),
                  label: Text(item.title),
                  avatar: const Icon(Icons.checkroom_outlined, size: 16),
                  onDeleted: () => onRemove(item),
                ),
              )
              .toList(),
        ),
      ],
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
      Container(
        width: 34,
        height: 25,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.freshSoft,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          number,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.x3),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
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
    if (collections.isEmpty) {
      return Container(
        key: const Key('composer-no-collection-items'),
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: AppColors.sunken,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: const Text(
          'No products yet. Add a retailer link above or create a collection without leaving this studio.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
      );
    }
    final populated = collections
        .where((collection) => collection.items.isNotEmpty)
        .toList();
    final empty = collections
        .where((collection) => collection.items.isEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (empty.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: AppColors.sunken,
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready for your first product',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.x2),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x1,
                  children: empty
                      .map(
                        (collection) => Chip(
                          key: Key('empty-collection-${collection.id}'),
                          avatar: const Icon(Icons.folder_outlined, size: 16),
                          label: Text(collection.name),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.x1),
                const Text(
                  'Tap Add product link and choose where to save it.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
        ],
        ...populated.map(
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
        ),
      ],
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
                GarmentImage(
                  source: item.imageUrl,
                  semanticLabel: item.title,
                  cacheWidth: 240,
                ),
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
          'No full-body photos yet. Add one from camera or gallery above and use it immediately.',
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
                  cacheWidth: 240,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
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
                  key: Key('outfit-preview-empty'),
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
                  key: const Key('outfit-preview-image'),
                  imageUrl!,
                  fit: BoxFit.cover,
                  cacheWidth:
                      (constraints.maxWidth *
                              MediaQuery.devicePixelRatioOf(context))
                          .round()
                          .clamp(480, 1600),
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: AppColors.sunken,
                    child: Icon(Icons.person, size: 48),
                  ),
                ),
              if (!generating && imageUrl != null)
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
