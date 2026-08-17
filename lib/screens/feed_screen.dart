import 'dart:async';

import 'package:flutter/material.dart';

import '../components/editorial_photo_frame.dart';
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
    this.uploadModelPhoto = ModelPhotoService.upload,
    this.generateTryOn = SocialService.createPostTryOn,
    this.profileName = 'YouCam Creator',
    this.profileAvatarUrl,
  });

  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final FetchPosts fetchPosts;
  final FetchModelPhotos fetchModelPhotos;
  final UploadModelPhoto uploadModelPhoto;
  final GeneratePostTryOn generateTryOn;
  final String profileName;
  final String? profileAvatarUrl;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const _filters = ['For you', 'Tops', 'Bottoms', 'Shoes', 'Dresses'];

  List<SocialPost> _posts = const [];
  String _activeFilter = _filters.first;
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
          _error = _friendlyError(error);
        });
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is TimeoutException) {
      return 'The feed server is not reachable right now. Keep the backend running and reconnect wireless debugging, then tap Retry.';
    }
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.contains('TimeoutException')
        ? 'The feed server is not reachable right now. Keep the backend running and reconnect wireless debugging, then tap Retry.'
        : message;
  }

  List<SocialPost> get _visiblePosts {
    if (_activeFilter == 'For you') return _posts;
    final category = switch (_activeFilter) {
      'Bottoms' => 'lower_body',
      'Shoes' => 'shoes',
      'Dresses' => 'full_body',
      _ => 'upper_body',
    };
    return _posts
        .where(
          (post) =>
              post.garments.any((garment) => garment.category == category),
        )
        .toList();
  }

  Future<void> _like(String postId) async {
    try {
      final updated = await SocialService.toggleLike(postId);
      if (!mounted) return;
      final index = _posts.indexWhere((post) => post.id == postId);
      if (index < 0) return;
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
          uploadModelPhoto: widget.uploadModelPhoto,
          generateTryOn: widget.generateTryOn,
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
            child: ListView(
              key: const Key('social-feed'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 84),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 10, 12, 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DISCOVER',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.8,
                              ),
                            ),
                            SizedBox(height: AppSpacing.x1),
                            Text(
                              'Fits worth trying',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'SHOP · TRY · POST',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x3,
                    AppSpacing.x1,
                    AppSpacing.x3,
                    AppSpacing.x2,
                  ),
                  child: Row(
                    children: [
                      for (var index = 0; index < _filters.length; index++) ...[
                        if (index > 0) const SizedBox(width: AppSpacing.x1),
                        Expanded(
                          child: _FeedFilterTile(
                            key: Key(
                              'feed-filter-${_filters[index].toLowerCase()}',
                            ),
                            label: _filters[index],
                            selected: _filters[index] == _activeFilter,
                            onTap: () =>
                                setState(() => _activeFilter = _filters[index]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_visiblePosts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.x8),
                    child: Center(
                      child: Text(
                        'No fits in this edit yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  _MasonryFeed(
                    posts: _visiblePosts,
                    onOpen: _open,
                    onLike: _like,
                    onTryOn: _tryOn,
                  ),
              ],
            ),
          ),
  );
}

class _FeedFilterTile extends StatelessWidget {
  const _FeedFilterTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label filter',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.textPrimary : AppColors.sunken,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? AppColors.textPrimary : AppColors.borderStrong,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: selected ? AppColors.textOnAccent : AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _MasonryFeed extends StatelessWidget {
  const _MasonryFeed({
    required this.posts,
    required this.onOpen,
    required this.onLike,
    required this.onTryOn,
  });

  final List<SocialPost> posts;
  final ValueChanged<SocialPost> onOpen;
  final ValueChanged<String> onLike;
  final ValueChanged<SocialPost> onTryOn;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columnCount = constraints.maxWidth >= 760 ? 3 : 2;
      final columns = List.generate(columnCount, (_) => <Widget>[]);
      final heights = List<double>.filled(columnCount, 0);
      for (var index = 0; index < posts.length; index++) {
        final shortest = heights.indexOf(
          heights.reduce((a, b) => a < b ? a : b),
        );
        final ratio = _DiscoveryCard.ratioFor(index);
        columns[shortest].add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x2),
            child: _DiscoveryCard(
              post: posts[index],
              imageRatio: ratio,
              onOpen: () => onOpen(posts[index]),
              onLike: () => onLike(posts[index].id),
              onTryOn: () => onTryOn(posts[index]),
            ),
          ),
        );
        heights[shortest] += 1 / ratio + 0.52;
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 3, 8, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < columns.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(child: Column(children: columns[index])),
            ],
          ],
        ),
      );
    },
  );
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    required this.post,
    required this.imageRatio,
    required this.onOpen,
    required this.onLike,
    required this.onTryOn,
  });

  final SocialPost post;
  final double imageRatio;
  final VoidCallback onOpen;
  final VoidCallback onLike;
  final VoidCallback onTryOn;

  // Every post uses the same catalog crop. Card copy can still create the
  // staggered Pinterest rhythm without cropping different people differently.
  static double ratioFor(int index) => 4 / 5;

  String get _categoryLabel {
    final category = post.garments.firstOrNull?.category;
    return switch (category) {
      'lower_body' => 'BOTTOMS',
      'full_body' => 'ONE PIECE',
      'shoes' => 'SHOES',
      'accessory' => 'ACCESSORIES',
      _ => 'TOPS',
    };
  }

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.raised,
    borderRadius: BorderRadius.circular(AppRadii.large),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialPhotoFrame(
            key: Key('editorial-frame-${post.id}'),
            aspectRatio: imageRatio,
            inset: 4,
            borderRadius: AppRadii.large,
            photoRadius: AppRadii.medium,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'post-${post.id}',
                  child: Image.network(
                    post.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.sunken,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x66000000)],
                      stops: [0.62, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: const Color(0xEFFFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      key: Key('try-on-post-${post.id}'),
                      onTap: onTryOn,
                      borderRadius: BorderRadius.circular(18),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'TRY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 9,
                  right: 9,
                  bottom: 9,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC1E1D1B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _categoryLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.sell_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${post.garments.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 3),
              child: Text(
                post.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 5, 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.sunken,
                  backgroundImage: post.author.avatarUrl == null
                      ? null
                      : NetworkImage(post.author.avatarUrl!),
                  child: post.author.avatarUrl == null
                      ? Text(
                          post.author.name.characters.first.toUpperCase(),
                          style: const TextStyle(fontSize: 9),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '@${post.author.handle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                InkResponse(
                  key: Key('like-${post.id}'),
                  onTap: onLike,
                  radius: 20,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      post.likedByMe ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: post.likedByMe
                          ? const Color(0xFFB64F55)
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Text('${post.likeCount}', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
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
