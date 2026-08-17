import 'package:flutter/material.dart';

import '../components/app_motion.dart';
import '../components/app_network_image.dart';
import '../components/app_state.dart';
import '../components/avatar.dart';
import '../components/editorial_photo_frame.dart';
import '../components/screen.dart';
import '../components/shoppable_pieces.dart';
import '../models/social_post.dart';
import '../services/model_photo_service.dart';
import '../services/saved_fit_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../utils/user_facing_error.dart';
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
    this.saveFit = SavedFitService.save,
    this.profileName = 'fitcheck creator',
    this.profileAvatarUrl,
    this.refreshGeneration = 0,
  });

  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final FetchPosts fetchPosts;
  final FetchModelPhotos fetchModelPhotos;
  final UploadModelPhoto uploadModelPhoto;
  final GeneratePostTryOn generateTryOn;
  final SaveFitDraft saveFit;
  final String profileName;
  final String? profileAvatarUrl;
  final int refreshGeneration;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const _filters = ['For you', 'Tops', 'Bottoms', 'Shoes', 'Dresses'];

  List<SocialPost> _posts = const [];
  String _activeFilter = _filters.first;
  bool _loading = true;
  String? _error;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshGeneration != widget.refreshGeneration) _load();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    try {
      final posts = await widget.fetchPosts();
      if (mounted && request == _loadRequest) {
        setState(() {
          _posts = posts;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && request == _loadRequest) {
        setState(() {
          _loading = false;
          _error = _friendlyError(error);
        });
      }
    }
  }

  String _friendlyError(Object error) {
    return userFacingError(
      error,
      fallback:
          'Your feed took a little too long. Tap Retry and we’ll give it another go.',
    );
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
            content: Text(
              userFacingError(
                error,
                fallback: 'That like didn’t stick. Try it once more.',
              ),
            ),
          ),
        );
      }
    }
  }

  void _open(SocialPost post) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(
          post: post,
          fetchModelPhotos: widget.fetchModelPhotos,
          uploadModelPhoto: widget.uploadModelPhoto,
          generateTryOn: widget.generateTryOn,
          saveFit: widget.saveFit,
        ),
      ),
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
          saveFit: widget.saveFit,
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
        ? const _FeedLoading()
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
                              'Looks worth trying',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'SHOP · TRY · MAKE IT YOURS',
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
                        'Nothing in this edit yet. Try another vibe.',
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
        final ratio = _DiscoveryCard.ratioFor(posts[index]);
        columns[shortest].add(
          AppReveal(
            key: ValueKey('feed-reveal-${posts[index].id}'),
            delay: Duration(milliseconds: (index * 35).clamp(0, 175)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x2),
              child: _DiscoveryCard(
                post: posts[index],
                imageRatio: ratio,
                onOpen: () => onOpen(posts[index]),
                onLike: () => onLike(posts[index].id),
                onTryOn: () => onTryOn(posts[index]),
              ),
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

  // Pinterest-like variation without layout jitter: a post always receives
  // the same height, even after a refresh or a like-state rebuild.
  static const _tileRatios = <double>[0.62, 0.68, 0.74, 0.80, 0.66, 0.77];

  static double ratioFor(SocialPost post) {
    var hash = 0x811C9DC5;
    for (final value in post.id.codeUnits) {
      hash = ((hash ^ value) * 0x01000193) & 0x7FFFFFFF;
    }
    return _tileRatios[hash % _tileRatios.length];
  }

  // Phone uploads are usually portrait photos with more breathing room than
  // the tightly framed studio seed images. Adapt the feed crop to the tile's
  // shape so generated posts keep the person prominent without over-cropping
  // already-short masonry cards.
  double get _editorialImageScale {
    if (!post.backgroundStyle.startsWith('youcam:')) return 1;
    return (0.80 / imageRatio).clamp(1.0, 1.24).toDouble();
  }

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
  Widget build(BuildContext context) {
    final logicalWidth = MediaQuery.sizeOf(context).width;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = ((logicalWidth / 2) * pixelRatio).round().clamp(
      320,
      1200,
    );
    return Material(
      color: AppColors.canvas,
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
                    child: Transform.scale(
                      key: Key('post-photo-crop-${post.id}'),
                      scale: _editorialImageScale,
                      alignment: Alignment.center,
                      child: AppNetworkImage(
                        url: post.imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: cacheWidth,
                        error: const ColoredBox(
                          color: AppColors.sunken,
                          child: Icon(Icons.broken_image_outlined),
                        ),
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
                    right: 8,
                    bottom: 9,
                    child: Material(
                      color: const Color(0xD9191A17),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        key: Key('shop-post-${post.id}'),
                        onTap: () =>
                            showShoppablePiecesSheet(context, post: post),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white,
                                size: 13,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'SHOP ${post.garments.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categoryLabel,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (post.caption.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      post.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 5, 6),
              child: Row(
                children: [
                  Avatar(
                    name: post.author.name,
                    imageUrl: post.author.avatarUrl,
                    size: 22,
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
                  Text(
                    '${post.likeCount}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 92),
    children: [
      const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Skeleton(width: 72, height: 9),
                SizedBox(height: AppSpacing.x2),
                _Skeleton(width: 172, height: 22),
              ],
            ),
          ),
          _Skeleton(width: 86, height: 10),
        ],
      ),
      const SizedBox(height: AppSpacing.x4),
      const _Skeleton(width: double.infinity, height: 34),
      const SizedBox(height: AppSpacing.x3),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < 2; index++) ...[
            if (index > 0) const SizedBox(width: AppSpacing.x2),
            const Expanded(
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 5,
                    child: _Skeleton(
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  SizedBox(height: AppSpacing.x2),
                  _Skeleton(width: double.infinity, height: 12),
                  SizedBox(height: AppSpacing.x1),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _Skeleton(width: 104, height: 10),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: const AppLoadingField(child: ColoredBox(color: AppColors.sunken)),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const AppEmptyState(
    icon: Icons.people_outline_rounded,
    title: 'Fresh looks incoming',
    message: 'Tap + to post the first fit and keep every piece shoppable.',
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      AppErrorState(message: message, onRetry: onRetry);
}
