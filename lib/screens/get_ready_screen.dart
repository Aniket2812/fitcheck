import 'package:flutter/material.dart';

import '../components/editorial_photo_frame.dart';
import '../components/garment_image.dart';
import '../components/garment_product_dialog.dart';
import '../models/saved_fit.dart';
import '../services/saved_fit_service.dart';
import '../theme/app_theme.dart';

class GetReadyScreen extends StatefulWidget {
  const GetReadyScreen({
    super.key,
    required this.fit,
    this.publishFit = SavedFitService.publish,
    this.deleteFit = SavedFitService.delete,
  });

  final SavedFit fit;
  final PublishSavedFit publishFit;
  final DeleteSavedFit deleteFit;

  @override
  State<GetReadyScreen> createState() => _GetReadyScreenState();
}

class _GetReadyScreenState extends State<GetReadyScreen> {
  late final TextEditingController _caption;
  bool _publishing = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _caption = TextEditingController(text: widget.fit.caption);
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final post = await widget.publishFit(widget.fit.id, _caption.text.trim());
      if (mounted) Navigator.pop(context, post);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved fit?'),
        content: const Text(
          'This removes the draft only. Your collections and photos stay saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep fit'),
          ),
          FilledButton(
            key: const Key('confirm-delete-saved-fit-button'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.deleteFit(widget.fit.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('get-ready-screen'),
    backgroundColor: AppColors.canvas,
    appBar: AppBar(
      title: const Text('Get ready'),
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          key: const Key('delete-saved-fit-button'),
          tooltip: 'Delete saved fit',
          onPressed: _publishing || _deleting ? null : _delete,
          icon: _deleting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
        ),
        const SizedBox(width: AppSpacing.x2),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.freshSoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Text(
                    'SAVED FIT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.fit.garments.length} ${widget.fit.garments.length == 1 ? 'piece' : 'pieces'}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            const Text(
              'Ready when you are.',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.x1),
            const Text(
              'This saved preview keeps your pose and original background. When you post, only the background changes to the Compete studio.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            EditorialPhotoFrame(
              key: Key('saved-fit-preview-${widget.fit.id}'),
              aspectRatio: 4 / 5,
              inset: 8,
              borderRadius: AppRadii.large,
              photoRadius: AppRadii.medium,
              child: GarmentImage(
                source: widget.fit.imageUrl,
                semanticLabel: 'Saved outfit preview',
                cacheWidth: 1200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Container(
              key: const Key('get-ready-background-note'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: AppSpacing.x2,
              ),
              decoration: BoxDecoration(
                color: AppColors.freshSoft,
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: const Row(
                children: [
                  Icon(Icons.accessibility_new_outlined, size: 18),
                  SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      'Same person. Same posture. Same framing. A clean Linen White background is applied only to the feed post.',
                      style: TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x5),
            const Text(
              'PIECES IN THIS FIT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            SizedBox(
              height: 128,
              child: ListView.separated(
                key: const Key('get-ready-pieces'),
                scrollDirection: Axis.horizontal,
                itemCount: widget.fit.garments.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.x2),
                itemBuilder: (context, index) {
                  final garment = widget.fit.garments[index];
                  return Material(
                    key: Key('get-ready-piece-${garment.id}'),
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => showGarmentProductDialog(
                        context,
                        postId: 'saved-${widget.fit.id}',
                        garment: garment,
                      ),
                      child: SizedBox(
                        width: 112,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.x2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: GarmentImage(
                                    source: garment.imageUrl,
                                    semanticLabel: garment.title,
                                    cacheWidth: 240,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.x1),
                              Text(
                                garment.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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
            const SizedBox(height: AppSpacing.x5),
            TextField(
              key: const Key('get-ready-caption'),
              controller: _caption,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Caption',
                hintText: 'Tell people about this fit…',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(
                _error!,
                key: const Key('get-ready-error'),
                style: const TextStyle(color: Color(0xFF8B5751)),
              ),
            ],
            const SizedBox(height: AppSpacing.x2),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('get-ready-post-button'),
                onPressed: _publishing || _deleting ? null : _publish,
                icon: _publishing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
                label: Text(
                  _publishing
                      ? 'Preparing studio post…'
                      : 'Post with studio background',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
