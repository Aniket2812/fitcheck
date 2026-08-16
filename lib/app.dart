import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'components/floating_nav.dart';
import 'models/closet_item.dart';
import 'models/social_post.dart';
import 'screens/create_post_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/search_screen.dart';
import 'services/ingest_service.dart';
import 'services/social_service.dart';
import 'theme/app_theme.dart';

class CompeteApp extends StatefulWidget {
  const CompeteApp({
    super.key,
    this.ingestLink,
    this.fetchPosts,
    this.persistCloset = true,
  });

  final IngestLink? ingestLink;
  final FetchPosts? fetchPosts;
  final bool persistCloset;

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

  @override
  void initState() {
    super.initState();
    if (widget.persistCloset) _loadCloset();
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

  Future<void> _openCreatePost() async {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    final post = await Navigator.of(context).push<SocialPost>(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(ingestLink: widget.ingestLink),
      ),
    );
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
                    fetchPosts: widget.fetchPosts ?? SocialService.fetchPosts,
                  ),
                  AppTab.saved => SavedScreen(
                    onSearch: () => setState(() => _searchOpen = true),
                    items: _items,
                  ),
                },
                FloatingNav(
                  active: _activeTab,
                  onChange: (tab) => setState(() => _activeTab = tab),
                  onAdd: _openCreatePost,
                ),
              ],
            ),
    );
  }
}
