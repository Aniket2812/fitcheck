import 'package:flutter/material.dart';

import '../components/editorial_photo_frame.dart';
import '../components/outfit_post_image.dart';
import '../models/social_post.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final SocialPost post;

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
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('@${_post.author.handle}'),
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
                child: EditorialPhotoFrame(
                  key: Key('editorial-frame-${_post.id}'),
                  aspectRatio: 0.77,
                  inset: 8,
                  borderRadius: 16,
                  photoRadius: 11,
                  label: 'COMPETE  /  OUTFIT EDIT',
                  child: OutfitPostImage(post: _post),
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
              const Divider(height: 1),
              if (_post.comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No comments yet. Start the conversation.',
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
                      hintText: 'Add a comment…',
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
