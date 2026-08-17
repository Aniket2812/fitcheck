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
import '../services/saved_fit_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../utils/user_facing_error.dart';

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
    this.saveFit = SavedFitService.save,
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
  final SaveFitDraft saveFit;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  final _scrollController = ScrollController();
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
  bool _savingFit = false;
  bool _addingProduct = false;
  bool _uploadingPhoto = false;
  int _activeStep = 0;
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
    return userFacingError(
      error,
      fallback:
          'Your closet didn’t load this time. Pull to refresh and try again.',
    );
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
              'Where should this piece live?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.x2),
            ..._collections.map(
              (collection) => ListTile(
                key: Key('composer-target-${collection.id}'),
                leading: const Icon(Icons.folder_outlined),
                title: Text(collection.name),
                subtitle: Text(
                  '${collection.items.length} ${collection.items.length == 1 ? 'piece' : 'pieces'}',
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.pop(sheetContext, collection),
              ),
            ),
            const Divider(),
            ListTile(
              key: const Key('composer-new-collection-from-picker'),
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Make a new collection'),
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
            child: const Text('Bring it in'),
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
    _scrollController.dispose();
    super.dispose();
  }

  void _showStep(int step) {
    final unlocked = switch (step) {
      0 => true,
      1 => _selectedItems.isNotEmpty,
      2 => _selectedItems.isNotEmpty && _selectedModelPhoto != null,
      _ => false,
    };
    if (!unlocked) return;
    setState(() {
      _activeStep = step;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: AppMotion.standard,
          curve: AppMotion.curve,
        );
      }
    });
  }

  void _continueFromPieces() {
    if (_selectedItems.isEmpty) {
      return _setError('Pick at least one piece to keep going.');
    }
    _showStep(1);
  }

  void _continueFromPhoto() {
    if (_selectedModelPhoto == null) {
      return _setError('Pick or add a full-body photo to keep going.');
    }
    _showStep(2);
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
      return _setError('Pick at least one piece for this look.');
    }
    if (modelPhoto == null) {
      return _setError('Pick a full-body photo for this look.');
    }
    if (!_youCamConfigured) {
      return _setError(
        'The fitting room is taking a breather. Try again shortly.',
      );
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
      _setError(
        userFacingError(
          error,
          fallback: 'This look didn’t come together. Give it another go.',
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _publish() async {
    if (_garments.isEmpty) {
      return _setError('Pick at least one piece for this look.');
    }
    if (_selectedModelPhoto == null) {
      return _setError('Pick a full-body photo for this look.');
    }
    if (_generating) {
      return _setError('Hang tight—your preview is still getting dressed.');
    }
    if (_previewUrl == null) {
      return _setError('Make the preview before posting this fit.');
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
      _setError(
        userFacingError(
          error,
          fallback: 'This fit didn’t post. Give it another go.',
        ),
      );
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _saveFit() async {
    if (_garments.isEmpty) {
      return _setError('Pick at least one piece for this look.');
    }
    if (_selectedModelPhoto == null) {
      return _setError('Pick a full-body photo for this look.');
    }
    if (_generating) {
      return _setError('Hang tight—your preview is still getting dressed.');
    }
    final preview = _previewUrl;
    if (preview == null) {
      return _setError('Make the preview before saving this fit.');
    }
    setState(() {
      _savingFit = true;
      _error = null;
    });
    try {
      await widget.saveFit(
        caption: _caption.text,
        imageUrl: preview,
        garments: _garments,
        modelPhotoId: _selectedModelPhoto?.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved for later. It’s waiting in your profile.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      _setError(
        userFacingError(
          error,
          fallback: 'This fit didn’t save. Give it another go.',
        ),
      );
      if (mounted) setState(() => _savingFit = false);
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

  Widget _stepCard({
    required int step,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) => Container(
    key: Key('composer-step-${step + 1}'),
    padding: const EdgeInsets.all(AppSpacing.x3),
    decoration: BoxDecoration(
      color: AppColors.raised,
      borderRadius: BorderRadius.circular(AppRadii.large),
      border: Border.all(color: AppColors.borderDefault),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(number: '0${step + 1}', title: title, subtitle: subtitle),
        const SizedBox(height: AppSpacing.x3),
        ...children,
      ],
    ),
  );

  Widget _buildPiecesStep() => _stepCard(
    step: 0,
    title: 'Pick your pieces',
    subtitle:
        'Mix from your collections or drop in a fresh link. We’ll keep the combo wearable.',
    children: [
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('composer-add-product-button'),
              onPressed: _addingProduct ? null : _addProduct,
              icon: _addingProduct
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_link, size: 18),
              label: Text(_addingProduct ? 'Bringing it in…' : 'Add a link'),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('composer-create-collection-button'),
              onPressed: _addingProduct ? null : _createCollection,
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('New collection'),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.x3),
      Row(
        children: [
          const Expanded(
            child: Text(
              'YOUR CLOSET PICKS',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
          TextButton.icon(
            key: const Key('composer-refresh-button'),
            onPressed: _load,
            icon: const Icon(Icons.sync_rounded, size: 15),
            label: const Text('Sync'),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.x1),
      _CollectionPicker(
        collections: _collections,
        selectedIds: _selectedIds,
        onToggle: _toggle,
      ),
      if (_selectedItems.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.x2),
        _SelectedPieces(items: _selectedItems, onRemove: _toggle),
      ],
      const SizedBox(height: AppSpacing.x3),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('composer-pieces-next'),
          onPressed: _selectedItems.isEmpty ? null : _continueFromPieces,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: Text(
            _selectedItems.isEmpty
                ? 'Pick a piece to keep going'
                : 'Style ${_selectedItems.length} ${_selectedItems.length == 1 ? 'piece' : 'pieces'}',
          ),
        ),
      ),
    ],
  );

  Widget _buildPhotoStep() => _stepCard(
    step: 1,
    title: 'Choose your photo',
    subtitle:
        'Choose the full-body shot that feels most you. We’ll keep the pose, framing and background.',
    children: [
      _SelectionSummary(
        icon: Icons.checkroom_outlined,
        title:
            '${_selectedItems.length} ${_selectedItems.length == 1 ? 'piece' : 'pieces'} selected',
        detail: _selectedItems.map((item) => item.title).join(' · '),
        actionLabel: 'Edit pieces',
        onAction: () => _showStep(0),
      ),
      const SizedBox(height: AppSpacing.x3),
      _PhotoPicker(
        photos: _modelPhotos,
        selected: _selectedModelPhoto,
        onSelect: _selectPhoto,
      ),
      const SizedBox(height: AppSpacing.x2),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('composer-add-photo-button'),
          onPressed: _uploadingPhoto ? null : _choosePhotoSource,
          icon: _uploadingPhoto
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_a_photo_outlined, size: 18),
          label: Text(
            _uploadingPhoto
                ? 'Saving photo…'
                : _modelPhotos.isEmpty
                ? 'Add a full-body photo'
                : 'Add another photo',
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.x3),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('composer-photo-next'),
          onPressed: _selectedModelPhoto == null ? null : _continueFromPhoto,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: Text(
            _selectedModelPhoto == null
                ? 'Pick a photo to keep going'
                : 'See the fit on you',
          ),
        ),
      ),
    ],
  );

  Widget _buildPreviewStep() => _stepCard(
    step: 2,
    title: 'See it on you',
    subtitle:
        'We’ll fit every piece while keeping your pose and original background exactly yours.',
    children: [
      _SelectionSummary(
        icon: Icons.person_outline_rounded,
        title: _selectedModelPhoto?.label ?? 'Selected photo',
        detail:
            '${_selectedItems.length} ${_selectedItems.length == 1 ? 'piece' : 'pieces'} ready to fit',
        actionLabel: 'Change',
        onAction: () => _showStep(1),
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
                ? 'Fitting every piece…'
                : _previewUrl == null
                ? 'Make the look'
                : 'Remix the look',
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
          onSelect: (index) => setState(() => _selectedGarmentIndex = index),
          onPlace: _placeTag,
        ),
      ),
      if (_previewUrl != null) ...[
        const SizedBox(height: AppSpacing.x2),
        const _PublishBackgroundNote(),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          key: const Key('composer-caption-field'),
          controller: _caption,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Caption',
            hintText: 'What’s the vibe?',
            border: OutlineInputBorder(),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('save-fit-button'),
                onPressed: _savingFit || _publishing ? null : _saveFit,
                icon: _savingFit
                    ? const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add_outlined, size: 17),
                label: Text(_savingFit ? 'Saving…' : 'Save fit'),
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: FilledButton.icon(
                key: const Key('publish-post-button'),
                onPressed: _publishing || _savingFit ? null : _publish,
                icon: _publishing
                    ? const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 17),
                label: Text(_publishing ? 'Posting…' : 'Post the fit'),
              ),
            ),
          ],
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    appBar: AppBar(
      title: const Text('Put the fit together'),
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
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
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                  children: [
                    _StudioProgress(
                      activeStep: _activeStep,
                      hasPieces: _selectedIds.isNotEmpty,
                      hasPhoto: _selectedModelPhoto != null,
                      hasPreview: _previewUrl != null,
                      onSelect: _showStep,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    AnimatedSwitcher(
                      duration: AppMotion.standard,
                      switchInCurve: AppMotion.curve,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.025, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: switch (_activeStep) {
                        1 => _buildPhotoStep(),
                        2 => _buildPreviewStep(),
                        _ => _buildPiecesStep(),
                      },
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.x3),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.x2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7EEEE),
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                          ),
                          child: Text(
                            _error!,
                            key: const Key('create-post-error'),
                            style: const TextStyle(color: Color(0xFF8B5751)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
  );
}

class _PublishBackgroundNote extends StatelessWidget {
  const _PublishBackgroundNote();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('publish-background-note'),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.x3,
      vertical: AppSpacing.x2,
    ),
    decoration: BoxDecoration(
      color: AppColors.freshSoft,
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.layers_outlined, size: 18),
        SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            'This preview and any saved fit keep your original background. Posting applies the Compete studio background without changing your pose.',
            style: TextStyle(fontSize: 12, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.icon,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
    decoration: BoxDecoration(
      color: AppColors.sunken,
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.raised,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17),
        ),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    ),
  );
}

class _StudioProgress extends StatelessWidget {
  const _StudioProgress({
    required this.activeStep,
    required this.hasPieces,
    required this.hasPhoto,
    required this.hasPreview,
    required this.onSelect,
  });

  final int activeStep;
  final bool hasPieces;
  final bool hasPhoto;
  final bool hasPreview;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
    decoration: BoxDecoration(
      color: AppColors.raised,
      borderRadius: BorderRadius.circular(AppRadii.large),
      border: Border.all(color: AppColors.borderDefault),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'FIT CHECK',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Text(
              'STEP ${activeStep + 1} OF 3',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Row(
          children: [
            _ProgressNode(
              index: 0,
              label: 'Pieces',
              active: activeStep == 0,
              complete: activeStep > 0,
              enabled: true,
              onTap: () => onSelect(0),
            ),
            _ProgressConnector(complete: activeStep > 0),
            _ProgressNode(
              index: 1,
              label: 'Photo',
              active: activeStep == 1,
              complete: activeStep > 1,
              enabled: hasPieces,
              onTap: () => onSelect(1),
            ),
            _ProgressConnector(complete: activeStep > 1),
            _ProgressNode(
              index: 2,
              label: hasPreview ? 'Ready' : 'Preview',
              active: activeStep == 2,
              complete: hasPreview,
              enabled: hasPieces && hasPhoto,
              onTap: () => onSelect(2),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ProgressConnector extends StatelessWidget {
  const _ProgressConnector({required this.complete});

  final bool complete;

  @override
  Widget build(BuildContext context) => Expanded(
    child: AnimatedContainer(
      duration: AppMotion.standard,
      curve: AppMotion.curve,
      height: 2,
      margin: const EdgeInsets.only(bottom: 17),
      color: complete ? AppColors.fresh : AppColors.borderDefault,
    ),
  );
}

class _ProgressNode extends StatelessWidget {
  const _ProgressNode({
    required this.index,
    required this.label,
    required this.active,
    required this.complete,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool active;
  final bool complete;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: active,
    enabled: enabled,
    label: '$label step',
    child: InkWell(
      key: Key('composer-progress-step-${index + 1}'),
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              key: active ? Key('composer-active-step-${index + 1}') : null,
              duration: AppMotion.standard,
              curve: AppMotion.curve,
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active || complete ? AppColors.fresh : AppColors.sunken,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active || complete
                      ? AppColors.fresh
                      : AppColors.borderStrong,
                ),
              ),
              child: AnimatedSwitcher(
                duration: AppMotion.quick,
                child: complete
                    ? const Icon(Icons.check_rounded, size: 15)
                    : Text(
                        '${index + 1}',
                        key: ValueKey(active),
                        style: TextStyle(
                          color: enabled
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
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
    final populated = collections
        .where((collection) => collection.items.isNotEmpty)
        .toList();
    if (populated.isEmpty) {
      return Container(
        key: const Key('composer-no-collection-items'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.sunken,
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.raised,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checkroom_outlined, size: 22),
            ),
            const SizedBox(height: AppSpacing.x2),
            const Text(
              'Start with a piece you love',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              collections.isEmpty
                  ? 'Drop a product link, then give it a collection.'
                  : 'Your ${collections.length} collections are ready. Drop in a link and choose its spot.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          'No full-body shots yet. Add one now and jump straight into the fit.',
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
                      Text('Your look lands here'),
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
