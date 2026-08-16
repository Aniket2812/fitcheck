import 'package:flutter/material.dart';

import '../components/avatar.dart';
import '../components/editorial_photo_frame.dart';
import '../models/social_post.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.fetchProfile = ProfileService.fetchMe,
    this.updateProfile = ProfileService.update,
    this.fetchPosts = SocialService.fetchPosts,
  });

  final FetchProfile fetchProfile;
  final UpdateProfile updateProfile;
  final FetchProfilePosts fetchPosts;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

typedef FetchProfilePosts = Future<List<SocialPost>> Function();

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  List<SocialPost> _posts = const [];
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
      final profile = await profileFuture;
      final posts = await postsFuture;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _posts = posts.where((post) => post.author.id == profile.id).toList();
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
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _ProfileError(message: _error!, onRetry: _load)
        : _ProfileContent(
            profile: _profile!,
            posts: _posts,
            onRefresh: _load,
            onEdit: _edit,
          ),
  );
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.posts,
    required this.onRefresh,
    required this.onEdit,
  });

  final UserProfile profile;
  final List<SocialPost> posts;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;

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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Avatar(
                    name: profile.name,
                    imageUrl: profile.avatarUrl,
                    size: 76,
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
                      color: AppColors.raised,
                      borderRadius: BorderRadius.circular(AppRadii.large),
                      border: Border.all(color: AppColors.borderDefault),
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
                itemBuilder: (context, index) => _ProfilePost(
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
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(32, 44, 32, 80),
    child: Column(
      children: [
        Icon(Icons.checkroom_outlined, size: 38, color: AppColors.textMuted),
        SizedBox(height: AppSpacing.x3),
        Text(
          'Your outfit story starts here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: AppSpacing.x1),
        Text(
          'Post your first virtual try-on and it will appear on this grid.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
      ],
    ),
  );
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 38),
          const SizedBox(height: AppSpacing.x3),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.x4),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
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
