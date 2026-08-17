import 'package:flutter/material.dart';

import '../components/app_motion.dart';
import '../components/editorial_photo_frame.dart';
import '../components/outfit_post_image.dart';
import '../components/shoppable_pieces.dart';
import '../models/social_post.dart';
import '../services/model_photo_service.dart';
import '../services/saved_fit_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../utils/user_facing_error.dart';
import 'try_on_yourself_screen.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.post,
    this.fetchModelPhotos = ModelPhotoService.fetchPhotos,
    this.uploadModelPhoto = ModelPhotoService.upload,
    this.generateTryOn = SocialService.createPostTryOn,
    this.saveFit = SavedFitService.save,
  });

  final SocialPost post;
  final FetchModelPhotos fetchModelPhotos;
  final UploadModelPhoto uploadModelPhoto;
  final GeneratePostTryOn generateTryOn;
  final SaveFitDraft saveFit;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _comment = TextEditingController();
  late SocialPost _post = widget.post;
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _like() async {
    try {
      final post = await SocialService.toggleLike(_post.id);
      if (mounted) setState(() => _post = post);
    } catch (error) {
      _message(error);
    }
  }

  Future<void> _sendComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final post = await SocialService.addComment(_post.id, text);
      if (!mounted) return;
      _comment.clear();
      setState(() => _post = post);
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _message(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          userFacingError(
            error,
            fallback: 'That didn’t land. Give it another go.',
          ),
        ),
      ),
    );
  }

  void _tryOn() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TryOnYourselfScreen(
          post: _post,
          fetchModelPhotos: widget.fetchModelPhotos,
          uploadModelPhoto: widget.uploadModelPhoto,
          generateTryOn: widget.generateTryOn,
          saveFit: widget.saveFit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('@${_post.author.handle}'),
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      actions: [
        if (_post.garments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton.icon(
              key: const Key('detail-try-on-button'),
              onPressed: _tryOn,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textOnAccent,
                backgroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                minimumSize: const Size(0, 36),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.auto_awesome, size: 15),
              label: const Text(
                'TRY ON',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              AppReveal(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
                  child: EditorialPhotoFrame(
                    key: Key('editorial-frame-${_post.id}'),
                    aspectRatio: 0.77,
                    inset: 8,
                    borderRadius: AppRadii.large,
                    photoRadius: AppRadii.medium,
                    label: 'FITCHECK  /  OUTFIT EDIT',
                    child: OutfitPostImage(post: _post),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('detail-like-button'),
                      onPressed: _like,
                      icon: Icon(
                        _post.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                      color: _post.likedByMe
                          ? const Color(0xFFB64F55)
                          : AppColors.textPrimary,
                    ),
                    Text('${_post.likeCount}'),
                    const SizedBox(width: AppSpacing.x3),
                    const Icon(Icons.chat_bubble_outline, size: 21),
                    const SizedBox(width: AppSpacing.x2),
                    Text('${_post.comments.length}'),
                  ],
                ),
              ),
              if (_post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '@${_post.author.handle} ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: _post.caption),
                      ],
                    ),
                  ),
                ),
              if (_post.garments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Shop the whole fit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${_post.garments.length} ${_post.garments.length == 1 ? 'item' : 'items'}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      ShoppablePiecesList(
                        post: _post,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.freshSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.forum_outlined, size: 15),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    const Expanded(
                      child: Text(
                        'Fit talk',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${_post.comments.length}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_post.comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 22),
                  child: Text(
                    'No comments yet. Say what you’re thinking.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._post.comments.map(
                  (comment) => ListTile(
                    title: Text(
                      '@${comment.author.handle}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(comment.text),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('comment-field'),
                    controller: _comment,
                    maxLength: 300,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendComment(),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: 'Drop a comment…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('send-comment-button'),
                  onPressed: _sending ? null : _sendComment,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
