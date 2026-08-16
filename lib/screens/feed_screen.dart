import 'package:flutter/material.dart';

import '../components/outfit_post_image.dart';
import '../components/screen.dart';
import '../models/social_post.dart';
import '../services/model_photo_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';
import 'try_on_yourself_screen.dart';

typedef FetchPosts = Future<List<SocialPost>> Function();

class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.onSearch,
    required this.onProfile,
    required this.fetchPosts,
    this.fetchModelPhotos = ModelPhotoService.fetchPhotos,
    this.generateOutfit = SocialService.createOutfitLook,
    this.profileName = 'YouCam Creator',
    this.profileAvatarUrl,
  });

  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final FetchPosts fetchPosts;
  final FetchModelPhotos fetchModelPhotos;
  final GenerateOutfitLook generateOutfit;
  final String profileName;
  final String? profileAvatarUrl;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<SocialPost> _posts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await widget.fetchPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _like(int index) async {
    try {
      final updated = await SocialService.toggleLike(_posts[index].id);
      if (!mounted) return;
      final posts = [..._posts]..[index] = updated;
      setState(() => _posts = posts);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  void _open(SocialPost post) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PostDetailScreen(post: post)),
    ).then((_) => _load());
  }

  void _tryOn(SocialPost post) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TryOnYourselfScreen(
          post: post,
          fetchModelPhotos: widget.fetchModelPhotos,
          generateOutfit: widget.generateOutfit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CompeteScreen(
    onSearch: widget.onSearch,
    onProfile: widget.onProfile,
    profileName: widget.profileName,
    profileAvatarUrl: widget.profileAvatarUrl,
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _ErrorState(message: _error!, onRetry: _load)
        : _posts.isEmpty
        ? const _EmptyState()
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              key: const Key('social-feed'),
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x4),
              itemBuilder: (context, index) => _PostCard(
                post: _posts[index],
                onOpen: () => _open(_posts[index]),
                onLike: () => _like(index),
                onTryOn: () => _tryOn(_posts[index]),
              ),
            ),
          ),
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onOpen,
    required this.onLike,
    required this.onTryOn,
  });
  final SocialPost post;
  final VoidCallback onOpen;
  final VoidCallback onLike;
  final VoidCallback onTryOn;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.raised,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: AppColors.sunken,
            backgroundImage: post.author.avatarUrl == null
                ? null
                : NetworkImage(post.author.avatarUrl!),
            child: post.author.avatarUrl == null
                ? Text(post.author.name.characters.first.toUpperCase())
                : null,
          ),
          title: Text(
            post.author.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('@${post.author.handle}'),
          trailing: TextButton.icon(
            key: Key('try-on-post-${post.id}'),
            onPressed: onTryOn,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Try on yourself'),
          ),
          onTap: onOpen,
        ),
        OutfitPostImage(post: post, onOpenPost: onOpen),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 0),
          child: Row(
            children: [
              IconButton(
                key: Key('like-${post.id}'),
                onPressed: onLike,
                icon: Icon(
                  post.likedByMe ? Icons.favorite : Icons.favorite_border,
                ),
                color: post.likedByMe
                    ? const Color(0xFFB64F55)
                    : AppColors.textPrimary,
              ),
              Text('${post.likeCount}'),
              IconButton(
                onPressed: onOpen,
                icon: const Icon(Icons.chat_bubble_outline),
              ),
              Text('${post.comments.length}'),
              const Spacer(),
              Text(
                '${post.garments.length} tagged',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '@${post.author.handle} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.x8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 42),
          SizedBox(height: AppSpacing.x3),
          Text(
            'No outfits yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: AppSpacing.x2),
          Text(
            'Tap + to publish the first fit and tag every shoppable garment.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.x3),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
