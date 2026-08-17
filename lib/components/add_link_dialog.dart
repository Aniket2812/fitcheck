import 'dart:async';

import 'package:flutter/material.dart';

import '../models/closet_item.dart';
import '../services/ingest_service.dart';
import '../theme/app_theme.dart';
import '../utils/user_facing_error.dart';
import 'garment_image.dart';

enum _AddStatus { idle, loading, error, done }

class AddLinkDialog extends StatefulWidget {
  const AddLinkDialog({
    super.key,
    required this.ingestLink,
    required this.onAdded,
  });

  final IngestLink ingestLink;
  final ValueChanged<ClosetItem> onAdded;

  @override
  State<AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<AddLinkDialog> {
  final _controller = TextEditingController();
  Timer? _progressTimer;
  int _waitSeconds = 0;
  _AddStatus _status = _AddStatus.idle;
  String _error = '';
  ClosetItem? _result;

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _reset() {
    _progressTimer?.cancel();
    _controller.clear();
    setState(() {
      _status = _AddStatus.idle;
      _error = '';
      _result = null;
      _waitSeconds = 0;
    });
  }

  void _startProgress() {
    _progressTimer?.cancel();
    _waitSeconds = 0;
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _status != _AddStatus.loading) return;
      setState(() => _waitSeconds += 1);
    });
  }

  void _stopProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> _submit() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() {
        _error = 'Paste a product link first.';
        _status = _AddStatus.error;
      });
      return;
    }

    setState(() {
      _status = _AddStatus.loading;
      _error = '';
    });
    _startProgress();

    try {
      final item = await widget.ingestLink(url);
      if (!mounted) return;
      _stopProgress();
      widget.onAdded(item);
      setState(() {
        _result = item;
        _status = _AddStatus.done;
      });
    } catch (error) {
      if (!mounted) return;
      _stopProgress();
      setState(() {
        _error = userFacingError(
          error,
          fallback:
              'Couldn’t pull that piece in. Check the link and try again.',
        );
        _status = _AddStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _status != _AddStatus.loading,
      child: Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _status == _AddStatus.done
                ? _DoneView(
                    item: _result!,
                    onAddAnother: _reset,
                    onDone: () => Navigator.of(context).pop(),
                  )
                : _FormView(
                    controller: _controller,
                    status: _status,
                    waitSeconds: _waitSeconds,
                    error: _error,
                    onChanged: () {
                      if (_error.isEmpty) return;
                      setState(() {
                        _error = '';
                        _status = _AddStatus.idle;
                      });
                    },
                    onCancel: () => Navigator.of(context).pop(),
                    onSubmit: _submit,
                  ),
          ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.controller,
    required this.status,
    required this.waitSeconds,
    required this.error,
    required this.onChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final _AddStatus status;
  final int waitSeconds;
  final String error;
  final VoidCallback onChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final loading = status == _AddStatus.loading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add a piece',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        const Text(
          'Drop a link from Myntra, AJIO, Amazon, Flipkart—or anywhere you found the piece. We’ll do the rest.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          key: const Key('product-link-field'),
          controller: controller,
          autofocus: true,
          enabled: !loading,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          autocorrect: false,
          onChanged: (_) => onChanged(),
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            hintText: 'https://www.myntra.com/...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            enabledBorder: _border(error.isNotEmpty),
            focusedBorder: _border(error.isNotEmpty, width: 1),
            disabledBorder: _border(false),
          ),
        ),
        if (error.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            error,
            key: const Key('add-link-error'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF8B5751)),
          ),
        ],
        const SizedBox(height: AppSpacing.x4),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                label: 'Cancel',
                onPressed: loading ? null : onCancel,
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: _PrimaryButton(
                key: const Key('extract-link-button'),
                onPressed: loading ? null : onSubmit,
                child: loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnAccent,
                        ),
                      )
                    : const Text('Bring it in'),
              ),
            ),
          ],
        ),
        if (loading) ...[
          const SizedBox(height: AppSpacing.x3),
          Center(
            child: Text(
              _progressMessage(waitSeconds),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ],
      ],
    );
  }

  String _progressMessage(int seconds) {
    final elapsed = seconds > 0 ? ' · ${seconds}s' : '';
    if (seconds < 20) {
      return 'Finding the product and getting it closet-ready$elapsed';
    }
    if (seconds < 90) {
      return 'Cleaning up the product shots—keep this open$elapsed';
    }
    return 'Still polishing this one—it’s a tricky photo$elapsed';
  }

  OutlineInputBorder _border(bool error, {double width = 0.5}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      borderSide: BorderSide(
        color: error ? const Color(0xFF8B5751) : AppColors.borderStrong,
        width: width,
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.item,
    required this.onAddAnother,
    required this.onDone,
  });

  final ClosetItem item;
  final VoidCallback onAddAnother;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your closet just got better',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        Container(
          width: double.infinity,
          height: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.photo,
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: AppColors.borderDefault, width: 0.5),
          ),
          child: GarmentImage(source: item.image, semanticLabel: item.title),
        ),
        const SizedBox(height: AppSpacing.x3),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        if (item.brand != null) ...[
          const SizedBox(height: AppSpacing.x1),
          Text(
            item.brand!,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.x4),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                label: 'Add another',
                onPressed: onAddAnother,
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: _PrimaryButton(
                key: const Key('done-adding-button'),
                onPressed: onDone,
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.hitTarget),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.borderStrong, width: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      child: Text(label),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.hitTarget),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textOnAccent,
        disabledBackgroundColor: AppColors.accent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      child: child,
    );
  }
}
