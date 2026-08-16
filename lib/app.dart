import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'components/floating_nav.dart';
import 'models/closet_item.dart';
import 'models/social_post.dart';
import 'models/user_profile.dart';
import 'screens/create_post_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/model_photos_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/search_screen.dart';
import 'services/ingest_service.dart';
import 'services/model_photo_service.dart';
import 'services/profile_service.dart';
import 'services/share_intent_service.dart';
import 'services/social_service.dart';
import 'theme/app_theme.dart';

class CompeteApp extends StatefulWidget {
  const CompeteApp({
    super.key,
    this.ingestLink,
    this.fetchPosts,
    this.persistCloset = true,
    this.shareIntentReceiver,
    this.fetchModelPhotos,
    this.checkYouCamConfigured,
    this.generateYouCamLook,
    this.fetchProfile,
    this.updateProfile,
  });

  final IngestLink? ingestLink;
  final FetchPosts? fetchPosts;
  final bool persistCloset;
  final ShareIntentReceiver? shareIntentReceiver;
  final FetchModelPhotos? fetchModelPhotos;
  final CheckYouCamConfigured? checkYouCamConfigured;
  final GenerateYouCamLook? generateYouCamLook;
  final FetchProfile? fetchProfile;
  final UpdateProfile? updateProfile;

  @override
  State<CompeteApp> createState() => _CompeteAppState();
}

class _CompeteAppState extends State<CompeteApp> {
  static const _closetKey = 'compete.closet.v1';

  final _navigatorKey = GlobalKey<NavigatorState>();
  AppTab _activeTab = AppTab.feed;
  bool _searchOpen = false;
  int _feedVersion = 0;
  List<ClosetItem> _items = const [];
  StreamSubscription<String>? _shareSubscription;
  late final ShareIntentReceiver _shareIntentReceiver;
  bool _composerOpen = false;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    if (widget.persistCloset) {
      _loadCloset();
      _loadHeaderProfile();
    }
    _shareIntentReceiver =
        widget.shareIntentReceiver ??
        (kIsWeb
            ? const NoopShareIntentReceiver()
            : SystemShareIntentReceiver());
    _listenForSharedProducts();
  }

  Future<void> _loadHeaderProfile() async {
    try {
      final profile = await (widget.fetchProfile ?? ProfileService.fetchMe)();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Feed and retry states already surface backend availability.
    }
  }

  void _listenForSharedProducts() {
    _shareSubscription = _shareIntentReceiver.productLinks.listen(
      _openSharedProduct,
      onError: (_) {},
    );
    _shareIntentReceiver
        .initialProductLink()
        .then((link) {
          if (link != null) _openSharedProduct(link);
        })
        .catchError((_) {});
  }

  void _openSharedProduct(String productUrl) {
    if (_composerOpen || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _composerOpen) return;
      _openCreatePost(initialProductUrl: productUrl);
      _shareIntentReceiver.reset().catchError((_) {});
    });
  }

  Future<void> _loadCloset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_closetKey);
      if (raw == null || !mounted) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      setState(() {
        _items = decoded
            .whereType<Map>()
            .map((item) => ClosetItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } catch (_) {
      // A corrupt or unreadable cache should not stop the app opening.
    }
  }

  Future<void> _saveCloset() async {
    if (!widget.persistCloset) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _closetKey,
        jsonEncode(_items.map((item) => item.toJson()).toList()),
      );
    } catch (_) {
      // The next successful add rewrites the complete closet.
    }
  }

  void _addItem(ClosetItem item) {
    setState(() => _items = [item, ..._items]);
    _saveCloset();
  }

  Future<void> _openCreatePost({String? initialProductUrl}) async {
    final context = _navigatorKey.currentContext;
    if (context == null || _composerOpen) return;
    _composerOpen = true;
    final post = await Navigator.of(context).push<SocialPost>(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          ingestLink: widget.ingestLink,
          initialProductUrl: initialProductUrl,
          fetchModelPhotos:
              widget.fetchModelPhotos ?? ModelPhotoService.fetchPhotos,
          checkYouCamConfigured:
              widget.checkYouCamConfigured ?? SocialService.youCamConfigured,
          generateLook:
              widget.generateYouCamLook ?? SocialService.createYouCamLook,
        ),
      ),
    );
    _composerOpen = false;
    if (post == null || !mounted) return;
    for (final garment in post.garments) {
      if (_items.any((item) => item.id == garment.id)) continue;
      _addItem(
        ClosetItem(
          id: garment.id,
          title: garment.title,
          image: garment.imageUrl,
          brand: garment.brand,
          price: garment.price,
          pageUrl: garment.buyUrl,
          originalImage: garment.originalImageUrl,
          category: garment.category,
        ),
      );
    }
    setState(() {
      _activeTab = AppTab.feed;
      _feedVersion += 1;
    });
  }

  Future<void> _openProfile() async {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          fetchProfile: widget.fetchProfile ?? ProfileService.fetchMe,
          updateProfile: widget.updateProfile ?? ProfileService.update,
          fetchPosts: widget.fetchPosts ?? SocialService.fetchPosts,
        ),
      ),
    );
    if (mounted) await _loadHeaderProfile();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'compete',
      debugShowCheckedModeBanner: false,
      theme: buildCompeteTheme(),
      home: _searchOpen
          ? SearchScreen(onClose: () => setState(() => _searchOpen = false))
          : Stack(
              children: [
                switch (_activeTab) {
                  AppTab.feed => FeedScreen(
                    key: ValueKey(_feedVersion),
                    onSearch: () => setState(() => _searchOpen = true),
                    onProfile: _openProfile,
                    profileName: _profile?.name ?? 'YouCam Creator',
                    profileAvatarUrl: _profile?.avatarUrl,
                    fetchPosts: widget.fetchPosts ?? SocialService.fetchPosts,
                  ),
                  AppTab.photos => ModelPhotosScreen(
                    onSearch: () => setState(() => _searchOpen = true),
                    onProfile: _openProfile,
                    profileName: _profile?.name ?? 'YouCam Creator',
                    profileAvatarUrl: _profile?.avatarUrl,
                    fetchPhotos:
                        widget.fetchModelPhotos ??
                        ModelPhotoService.fetchPhotos,
                  ),
                  AppTab.saved => SavedScreen(
                    onSearch: () => setState(() => _searchOpen = true),
                    onProfile: _openProfile,
                    profileName: _profile?.name ?? 'YouCam Creator',
                    profileAvatarUrl: _profile?.avatarUrl,
                    items: _items,
                  ),
                },
                FloatingNav(
                  active: _activeTab,
                  onChange: (tab) => setState(() => _activeTab = tab),
                  onAdd: () => _openCreatePost(),
                ),
              ],
            ),
    );
  }
}
