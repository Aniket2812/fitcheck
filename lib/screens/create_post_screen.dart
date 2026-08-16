import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../components/garment_image.dart';
import '../models/social_post.dart';
import '../services/ingest_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, this.ingestLink, this.initialProductUrl});

  final IngestLink? ingestLink;
  final String? initialProductUrl;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  final _productLink = TextEditingController();
  final _picker = ImagePicker();
  XFile? _photo;
  Uint8List? _photoBytes;
  String? _youCamImageUrl;
  List<PostGarment> _garments = const [];
  int? _selectedGarment;
  bool _extracting = false;
  bool _publishing = false;
  bool _generating = false;
  bool _youCamConfigured = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SocialService.youCamConfigured().then((value) {
      if (mounted) setState(() => _youCamConfigured = value);
    });
    final initialProductUrl = widget.initialProductUrl?.trim();
    if (initialProductUrl != null && initialProductUrl.isNotEmpty) {
      _productLink.text = initialProductUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) => _addGarment());
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    _productLink.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = picked;
      _photoBytes = bytes;
      _youCamImageUrl = null;
      _error = null;
    });
  }

  Future<void> _showPhotoSource() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _choosePhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _choosePhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
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
      final index = _garments.length;
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
        y: (0.25 + index * 0.18).clamp(0.15, 0.85),
      );
      if (!mounted) return;
      setState(() {
        _garments = [..._garments, garment];
        _selectedGarment = _garments.length - 1;
        _productLink.clear();
      });
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
    if (_photo == null || _garments.isEmpty) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final url = await SocialService.createYouCamLook(
        photo: _photo!,
        garment: _garments.first,
      );
      if (mounted) setState(() => _youCamImageUrl = url);
    } catch (error) {
      _setError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _publish() async {
    if (_photo == null) return _setError('Choose an outfit photo.');
    if (_garments.isEmpty) return _setError('Tag at least one garment.');
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final post = await SocialService.createPost(
        photo: _youCamImageUrl == null ? _photo : null,
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
              AspectRatio(
                aspectRatio: 4 / 5,
                child: _photoBytes == null
                    ? _PhotoPlaceholder(onTap: _showPhotoSource)
                    : _TaggablePhoto(
                        bytes: _photoBytes!,
                        networkUrl: _youCamImageUrl,
                        garments: _garments,
                        selected: _selectedGarment,
                        onSelect: (index) =>
                            setState(() => _selectedGarment = index),
                        onPlace: _placeTag,
                        onReplace: _showPhotoSource,
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
              const SizedBox(height: AppSpacing.x3),
              TextField(
                key: const Key('post-product-link-field'),
                controller: _productLink,
                enabled: !_extracting,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _addGarment(),
                decoration: InputDecoration(
                  labelText: 'Product buying link',
                  hintText: 'Paste Myntra, Zara, Nike…',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    key: const Key('tag-product-button'),
                    onPressed: _extracting ? null : _addGarment,
                    icon: _extracting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_link),
                  ),
                ),
              ),
              if (_garments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x3),
                const Text(
                  'Tap a garment, then tap its position in the photo.',
                ),
                const SizedBox(height: AppSpacing.x2),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _garments.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.x2),
                    itemBuilder: (context, index) => _GarmentChip(
                      garment: _garments[index],
                      number: index + 1,
                      selected: index == _selectedGarment,
                      onTap: () => setState(() => _selectedGarment = index),
                      onRemove: () {
                        final updated = [..._garments]..removeAt(index);
                        setState(() {
                          _garments = updated;
                          _selectedGarment = updated.isEmpty ? null : 0;
                        });
                      },
                    ),
                  ),
                ),
              ],
              if (_youCamConfigured &&
                  _photo != null &&
                  _garments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x4),
                OutlinedButton.icon(
                  key: const Key('youcam-generate-button'),
                  onPressed: _generating ? null : _generateWithYouCam,
                  icon: _generating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _generating
                        ? 'YouCam is creating your look…'
                        : 'Generate fit with YouCam',
                  ),
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

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('choose-outfit-photo'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadii.large),
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.sunken,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 42),
          SizedBox(height: AppSpacing.x3),
          Text(
            'Add your outfit photo',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: AppSpacing.x1),
          Text(
            'Camera or gallery',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _TaggablePhoto extends StatelessWidget {
  const _TaggablePhoto({
    required this.bytes,
    required this.networkUrl,
    required this.garments,
    required this.selected,
    required this.onSelect,
    required this.onPlace,
    required this.onReplace,
  });

  final Uint8List bytes;
  final String? networkUrl;
  final List<PostGarment> garments;
  final int? selected;
  final ValueChanged<int> onSelect;
  final void Function(TapDownDetails, Size) onPlace;
  final VoidCallback onReplace;

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
              networkUrl == null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : Image.network(networkUrl!, fit: BoxFit.cover),
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
              Positioned(
                right: 10,
                top: 10,
                child: IconButton.filledTonal(
                  onPressed: onReplace,
                  tooltip: 'Replace photo',
                  icon: const Icon(Icons.edit_outlined, size: 19),
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
