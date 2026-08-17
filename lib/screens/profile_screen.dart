import 'package:flutter/material.dart';

import '../components/app_motion.dart';
import '../components/app_state.dart';
import '../components/avatar.dart';
import '../components/editorial_photo_frame.dart';
import '../components/garment_image.dart';
import '../models/saved_fit.dart';
import '../models/social_post.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/saved_fit_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import 'get_ready_screen.dart';
import 'post_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.fetchProfile = ProfileService.fetchMe,
    this.updateProfile = ProfileService.update,
    this.fetchPosts = SocialService.fetchPosts,
    this.fetchSavedFits = SavedFitService.fetch,
    this.publishSavedFit = SavedFitService.publish,
    this.deleteSavedFit = SavedFitService.delete,
    this.onPublished,
  });

  final FetchProfile fetchProfile;
  final UpdateProfile updateProfile;
  final FetchProfilePosts fetchPosts;
  final FetchSavedFits fetchSavedFits;
  final PublishSavedFit publishSavedFit;
  final DeleteSavedFit deleteSavedFit;
  final ValueChanged<SocialPost>? onPublished;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

typedef FetchProfilePosts = Future<List<SocialPost>> Function();

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  List<SocialPost> _posts = const [];
  List<SavedFit> _savedFits = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profileFuture = widget.fetchProfile();
      final postsFuture = widget.fetchPosts();
      final savedFitsFuture = widget.fetchSavedFits();
      final profile = await profileFuture;
      final posts = await postsFuture;
      final savedFits = await savedFitsFuture;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _posts = posts.where((post) => post.author.id == profile.id).toList();
        _savedFits = savedFits;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openSavedFit(SavedFit fit) async {
    final post = await Navigator.push<SocialPost>(
      context,
      MaterialPageRoute(
        builder: (_) => GetReadyScreen(
          fit: fit,
          publishFit: widget.publishSavedFit,
          deleteFit: widget.deleteSavedFit,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
    if (post != null && mounted) {
      widget.onPublished?.call(post);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your saved fit is now live.')),
      );
    }
  }

  Future<void> _edit() async {
    final profile = _profile;
    if (profile == null) return;
    final updated = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.raised,
      builder: (_) => _EditProfileSheet(
        profile: profile,
        updateProfile: widget.updateProfile,
      ),
    );
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('profile-screen'),
    backgroundColor: AppColors.canvas,
    appBar: AppBar(
      title: const Text(
        'Profile',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      centerTitle: true,
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          key: const Key('profile-edit-icon'),
          onPressed: _profile == null ? null : _edit,
          tooltip: 'Edit profile',
          icon: const Icon(Icons.edit_outlined, size: 21),
        ),
        const SizedBox(width: AppSpacing.x2),
      ],
    ),
    body: _loading
        ? const _ProfileLoading()
        : _error != null
        ? AppErrorState(message: _error!, onRetry: _load)
        : _ProfileContent(
            profile: _profile!,
            posts: _posts,
            savedFits: _savedFits,
            onRefresh: _load,
            onEdit: _edit,
            onOpenSavedFit: _openSavedFit,
          ),
  );
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.posts,
    required this.savedFits,
    required this.onRefresh,
    required this.onEdit,
    required this.onOpenSavedFit,
  });

  final UserProfile profile;
  final List<SocialPost> posts;
  final List<SavedFit> savedFits;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;
  final ValueChanged<SavedFit> onOpenSavedFit;

  @override
  Widget build(BuildContext context) {
    final likes = posts.fold<int>(0, (total, post) => total + post.likeCount);
    final pieces = posts.fold<int>(
      0,
      (total, post) => total + post.garments.length,
    );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AppReveal(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: AppColors.freshSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Avatar(
                        name: profile.name,
                        imageUrl: profile.avatarUrl,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    Text(
                      profile.name,
                      key: const Key('profile-name'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      '@${profile.handle}',
                      key: const Key('profile-handle'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (profile.bio.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.x3),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Text(
                          profile.bio,
                          key: const Key('profile-bio'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.x4),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.sunken,
                        borderRadius: BorderRadius.circular(AppRadii.large),
                      ),
                      child: Row(
                        children: [
                          _Stat(value: posts.length, label: 'Outfits'),
                          const _StatDivider(),
                          _Stat(value: likes, label: 'Likes'),
                          const _StatDivider(),
                          _Stat(value: pieces, label: 'Pieces'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        key: const Key('profile-edit-button'),
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.borderStrong),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        child: const Text('Edit profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.bookmarks_outlined, size: 16),
                  const SizedBox(width: AppSpacing.x2),
                  const Text(
                    'SAVED FITS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.freshSoft,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      '${savedFits.length}',
                      key: const Key('saved-fits-count'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (savedFits.isEmpty)
            const SliverToBoxAdapter(child: _EmptySavedFits())
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: 224,
                child: ListView.separated(
                  key: const Key('saved-fits-list'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  itemCount: savedFits.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.x2),
                  itemBuilder: (context, index) => AppReveal(
                    delay: Duration(milliseconds: index * 35),
                    child: _SavedFitCard(
                      fit: savedFits[index],
                      onTap: () => onOpenSavedFit(savedFits[index]),
                    ),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.grid_view_rounded, size: 16),
                  SizedBox(width: AppSpacing.x2),
                  Text(
                    'OUTFITS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (posts.isEmpty)
            const SliverToBoxAdapter(child: _EmptyProfilePosts())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.8,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) => AppReveal(
                  key: ValueKey('profile-post-${posts[index].id}'),
                  delay: Duration(milliseconds: (index * 30).clamp(0, 150)),
                  child: _ProfilePost(
                    post: posts[index],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PostDetailScreen(post: posts[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SavedFitCard extends StatelessWidget {
  const _SavedFitCard({required this.fit, required this.onTap});

  final SavedFit fit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 146,
    child: Material(
      key: Key('saved-fit-card-${fit.id}'),
      color: AppColors.raised,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: GarmentImage(
                  source: fit.imageUrl,
                  semanticLabel: 'Saved fit preview',
                  cacheWidth: 520,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fit.caption.isEmpty ? 'Untitled fit' : fit.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${fit.garments.length} pieces · Get ready',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptySavedFits extends StatelessWidget {
  const _EmptySavedFits();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.sunken,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: const Row(
        children: [
          Icon(Icons.bookmark_add_outlined, color: AppColors.textMuted),
          SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              'Save a generated look from Build an outfit and it will wait here until you are ready.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: AppColors.borderDefault);
}

class _ProfilePost extends StatelessWidget {
  const _ProfilePost({required this.post, required this.onTap});
  final SocialPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadii.medium),
    child: EditorialPhotoFrame(
      key: Key('editorial-frame-${post.id}'),
      aspectRatio: 0.8,
      inset: 6,
      borderRadius: AppRadii.medium,
      photoRadius: 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            post.imageUrl,
            fit: BoxFit.cover,
            cacheWidth: 720,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: AppColors.sunken,
              child: Icon(Icons.checkroom, color: AppColors.textMuted),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${post.garments.length} ${post.garments.length == 1 ? 'piece' : 'pieces'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textOnAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyProfilePosts extends StatelessWidget {
  const _EmptyProfilePosts();

  @override
  Widget build(BuildContext context) => const AppEmptyState(
    icon: Icons.checkroom_outlined,
    title: 'Your outfit story starts here.',
    message: 'Post your first virtual try-on and it will appear on this grid.',
  );
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
    child: Column(
      children: [
        const AppLoadingField(
          borderRadius: AppRadii.pill,
          child: SizedBox.square(
            dimension: 86,
            child: ColoredBox(color: AppColors.sunken),
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        const AppLoadingField(
          child: SizedBox(
            width: 160,
            height: 20,
            child: ColoredBox(color: AppColors.sunken),
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        AppLoadingField(
          child: SizedBox(
            width: double.infinity,
            height: 64,
            child: ColoredBox(color: AppColors.sunken),
          ),
        ),
      ],
    ),
  );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile, required this.updateProfile});

  final UserProfile profile;
  final UpdateProfile updateProfile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _handle;
  late final TextEditingController _bio;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _handle = TextEditingController(text: widget.profile.handle);
    _bio = TextEditingController(text: widget.profile.bio);
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = await widget.updateProfile(
        name: _name.text.trim(),
        handle: _handle.text.trim(),
        bio: _bio.text.trim(),
      );
      if (mounted) Navigator.pop(context, profile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            const Text(
              'Edit profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.x4),
            TextField(
              key: const Key('profile-name-field'),
              controller: _name,
              maxLength: 40,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              key: const Key('profile-handle-field'),
              controller: _handle,
              maxLength: 20,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Handle',
                prefixText: '@',
                helperText: 'Letters, numbers, and underscores',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              key: const Key('profile-bio-field'),
              controller: _bio,
              maxLength: 160,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Your style in a sentence…',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(_error!, style: const TextStyle(color: Color(0xFF8B5751))),
            ],
            const SizedBox(height: AppSpacing.x3),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('profile-save-button'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
