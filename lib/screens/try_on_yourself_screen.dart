import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../components/diagonal_processing_overlay.dart';
import '../models/model_photo.dart';
import '../models/post_try_on_result.dart';
import '../models/social_post.dart';
import '../services/model_photo_service.dart';
import '../services/saved_fit_service.dart';
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
    this.generateTryOn = SocialService.createPostTryOn,
    this.saveFit = SavedFitService.save,
  });

  final SocialPost post;
  final FetchModelPhotos fetchModelPhotos;
  final UploadModelPhoto uploadModelPhoto;
  final PickFullBodyPhoto pickPhoto;
  final GeneratePostTryOn generateTryOn;
  final SaveFitDraft saveFit;

  @override
  State<TryOnYourselfScreen> createState() => _TryOnYourselfScreenState();
}

class _TryOnYourselfScreenState extends State<TryOnYourselfScreen> {
  List<ModelPhoto> _photos = const [];
  ModelPhoto? _selected;
  PostTryOnResult? _result;
  String? _error;
  bool _loading = true;
  bool _uploading = false;
  bool _generating = false;
  bool _saving = false;
  bool _saved = false;
  bool _showOriginal = false;
  String? _saveError;

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
        _error = _friendlyError(error, phase: 'photos');
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 19),
                  SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      'For the cleanest fit: one person, head to feet visible, facing forward, standing straight with arms slightly away from the body.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
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
        _result = null;
        _saved = false;
        _saveError = null;
        _showOriginal = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error, phase: 'upload'));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _friendlyError(Object error, {required String phase}) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('ClientConnection') ||
        message.contains('SocketException') ||
        message.contains('TimeoutException')) {
      if (phase == 'try-on') {
        return 'The fitting service did not finish in time. Your original photo is unchanged; retry this look.';
      }
      if (phase == 'save') {
        return 'Could not save this fit. Keep the backend running and reconnect wireless debugging, then try again.';
      }
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
      _result = null;
      _saved = false;
      _saveError = null;
      _showOriginal = false;
      _error = null;
    });
    try {
      final result = await widget.generateTryOn(
        modelPhoto: photo,
        post: widget.post,
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error, phase: 'try-on'));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _saveResult() async {
    final result = _result;
    final photo = _selected;
    if (result == null || photo == null || _saving || _saved) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.saveFit(
        caption: widget.post.caption,
        imageUrl: result.imageUrl,
        garments: widget.post.garments,
        modelPhotoId: photo.id,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fit saved. Find it in Profile → Saved Fits.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = _friendlyError(error, phase: 'save');
      });
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
                _result == null
                    ? 'See this complete fit on you.'
                    : 'Your version is ready.',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              const _CompositionPromise(),
              const SizedBox(height: AppSpacing.x2),
              GestureDetector(
                onLongPressStart: _result == null
                    ? null
                    : (_) => setState(() => _showOriginal = true),
                onLongPressEnd: _result == null
                    ? null
                    : (_) => setState(() => _showOriginal = false),
                onLongPressCancel: _result == null
                    ? null
                    : () => setState(() => _showOriginal = false),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.large),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Image.network(
                            key: ValueKey(
                              _showOriginal
                                  ? 'original'
                                  : _result?.imageUrl ?? 'selected',
                            ),
                            _showOriginal
                                ? _selected?.imageUrl ?? widget.post.imageUrl
                                : _result?.imageUrl ??
                                      _selected?.imageUrl ??
                                      widget.post.imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth:
                                (MediaQuery.sizeOf(context).width *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .round()
                                    .clamp(480, 1600),
                            filterQuality: FilterQuality.medium,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: AppColors.sunken,
                              child: Icon(Icons.person_outline, size: 52),
                            ),
                          ),
                        ),
                        if (_generating)
                          DiagonalProcessingOverlay(
                            key: const Key('try-on-processing-animation'),
                            label: 'Fitting every piece',
                            points: widget.post.garments
                                .map((garment) => Offset(garment.x, garment.y))
                                .toList(growable: false),
                          ),
                        if (_result != null && !_generating)
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: _CompareBadge(
                              showingOriginal: _showOriginal,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.x2),
                _ResultSummary(
                  appliedCount: _result!.appliedCount,
                  compositionPreserved: _result!.preservesSourceComposition,
                ),
                const SizedBox(height: AppSpacing.x2),
                _SaveFitAction(
                  saving: _saving,
                  saved: _saved,
                  error: _saveError,
                  onSave: _saveResult,
                ),
              ],
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
                        'Use one clear, front-facing head-to-feet photo. It will be checked for YouCam compatibility and saved in My Photos.',
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
                      onPressed: _uploading || _generating || _saving
                          ? null
                          : _chooseSource,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 17),
                      label: const Text('Add new'),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Pick the pose and background you want to keep in the result.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
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
                        onTap: _generating || _saving
                            ? null
                            : () => setState(() {
                                _selected = photo;
                                _result = null;
                                _saved = false;
                                _saveError = null;
                                _showOriginal = false;
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
                              cacheWidth: 220,
                              filterQuality: FilterQuality.medium,
                              gaplessPlayback: true,
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
                  onPressed: _generating || _saving ? null : _generate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    _generating
                        ? 'Fitting every piece…'
                        : _result == null
                        ? 'Try this look'
                        : 'Try again',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.x3),
                _TryOnErrorCard(
                  message: _error!,
                  canRetry: _selected != null && !_generating,
                  onRetry: _generate,
                ),
              ],
            ],
          ),
  );
}

class _CompositionPromise extends StatelessWidget {
  const _CompositionPromise();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.x2,
      vertical: AppSpacing.x2,
    ),
    decoration: BoxDecoration(
      color: AppColors.sunken,
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: const Row(
      children: [
        Icon(Icons.center_focus_strong_outlined, size: 17),
        SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            'Your selected photo stays the base — same pose, framing and background. Only the complete outfit is transferred.',
            style: TextStyle(fontSize: 12, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _CompareBadge extends StatelessWidget {
  const _CompareBadge({required this.showingOriginal});

  final bool showingOriginal;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.textPrimary.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        showingOriginal ? 'ORIGINAL PHOTO' : 'HOLD TO COMPARE',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    ),
  );
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    required this.appliedCount,
    required this.compositionPreserved,
  });

  final int appliedCount;
  final bool compositionPreserved;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('try-on-result-summary'),
    padding: const EdgeInsets.all(AppSpacing.x2),
    decoration: BoxDecoration(
      color: AppColors.raised,
      border: Border.all(color: AppColors.borderDefault),
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle, size: 19),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            '$appliedCount pieces transferred as one complete look'
            '${compositionPreserved ? ' · source composition retained' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

class _SaveFitAction extends StatelessWidget {
  const _SaveFitAction({
    required this.saving,
    required this.saved,
    required this.error,
    required this.onSave,
  });

  final bool saving;
  final bool saved;
  final String? error;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('try-on-save-fit-card'),
    padding: const EdgeInsets.all(AppSpacing.x2),
    decoration: BoxDecoration(
      color: saved ? const Color(0xFFF0F5EF) : AppColors.raised,
      border: Border.all(
        color: saved ? const Color(0xFFBDD0B9) : AppColors.borderDefault,
      ),
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    saved ? 'Ready for later' : 'Keep this version',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    saved
                        ? 'Saved privately with every shoppable piece.'
                        : 'Save privately, then post it anytime from Profile.',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            FilledButton.icon(
              key: const Key('save-try-on-fit-button'),
              onPressed: saving || saved ? null : onSave,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      saved
                          ? Icons.bookmark_added_outlined
                          : Icons.bookmark_add_outlined,
                      size: 18,
                    ),
              label: Text(
                saving
                    ? 'Saving…'
                    : saved
                    ? 'Saved'
                    : 'Save fit',
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            error!,
            key: const Key('save-try-on-fit-error'),
            style: const TextStyle(
              color: Color(0xFF6F4541),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ],
    ),
  );
}

class _TryOnErrorCard extends StatelessWidget {
  const _TryOnErrorCard({
    required this.message,
    required this.canRetry,
    required this.onRetry,
  });

  final String message;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('try-on-error'),
    padding: const EdgeInsets.all(AppSpacing.x2),
    decoration: BoxDecoration(
      color: const Color(0xFFF7EEEE),
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: Color(0xFF8B5751), size: 19),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF6F4541), height: 1.35),
          ),
        ),
        if (canRetry)
          TextButton(
            key: const Key('retry-try-on-button'),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
      ],
    ),
  );
}
