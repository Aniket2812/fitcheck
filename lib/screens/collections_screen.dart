import 'package:flutter/material.dart';

import '../components/app_motion.dart';
import '../components/app_page_intro.dart';
import '../components/app_state.dart';
import '../components/garment_image.dart';
import '../components/screen.dart';
import '../models/fashion_collection.dart';
import '../services/collection_service.dart';
import '../services/ingest_service.dart';
import '../theme/app_theme.dart';

enum _CollectionFilter { all, ready, empty }

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({
    super.key,
    required this.onSearch,
    required this.onProfile,
    this.profileName = 'YouCam Creator',
    this.profileAvatarUrl,
    this.fetchCollections = CollectionService.fetchCollections,
    this.createCollection = CollectionService.createCollection,
    this.saveItem = CollectionService.addItem,
    this.deleteItem = CollectionService.deleteItem,
    this.ingestLink = IngestService.ingest,
    this.refreshGeneration = 0,
  });

  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final String profileName;
  final String? profileAvatarUrl;
  final FetchCollections fetchCollections;
  final CreateFashionCollection createCollection;
  final SaveCollectionItem saveItem;
  final DeleteCollectionItem deleteItem;
  final IngestLink ingestLink;
  final int refreshGeneration;

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<FashionCollection> _collections = const [];
  bool _loading = true;
  String? _busyCollectionId;
  String? _error;
  _CollectionFilter _filter = _CollectionFilter.all;
  int _loadRequest = 0;

  int get _pieceCount => _collections.fold(
    0,
    (total, collection) => total + collection.items.length,
  );

  int get _readyCount =>
      _collections.where((collection) => collection.items.isNotEmpty).length;

  List<FashionCollection> get _visibleCollections => switch (_filter) {
    _CollectionFilter.ready =>
      _collections.where((collection) => collection.items.isNotEmpty).toList(),
    _CollectionFilter.empty =>
      _collections.where((collection) => collection.items.isEmpty).toList(),
    _CollectionFilter.all => _collections,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CollectionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshGeneration != widget.refreshGeneration) _load();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    try {
      final collections = await widget.fetchCollections();
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _collections = collections;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _createCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New collection'),
        content: TextField(
          key: const Key('new-collection-name'),
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Weekend fits',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('create-collection-button'),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      final collection = await widget.createCollection(name);
      if (mounted) setState(() => _collections = [..._collections, collection]);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _addLink(FashionCollection collection) async {
    final controller = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add to ${collection.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the retailer’s product page. We’ll fetch its image, details and buying link.',
            ),
            const SizedBox(height: AppSpacing.x3),
            TextField(
              key: const Key('collection-product-link'),
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.link_rounded, size: 19),
                hintText: 'Myntra, AJIO, Amazon…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add product'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (link == null || link.isEmpty) return;
    setState(() => _busyCollectionId = collection.id);
    try {
      final extracted = await widget.ingestLink(link);
      await widget.saveItem(collection.id, extracted);
      await _load();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busyCollectionId = null);
    }
  }

  Future<void> _quickAdd() async {
    if (_collections.isEmpty) {
      await _createCollection();
      return;
    }
    final selected = await showModalBottomSheet<FashionCollection>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  'Choose a collection',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _collections.length,
                  itemBuilder: (context, index) {
                    final collection = _collections[index];
                    final visual = _collectionVisual(collection.kind);
                    return ListTile(
                      key: Key('quick-add-collection-${collection.id}'),
                      leading: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: visual.color,
                          borderRadius: BorderRadius.circular(AppRadii.small),
                        ),
                        child: Icon(visual.icon, size: 18),
                      ),
                      title: Text(collection.name),
                      subtitle: Text(
                        '${collection.items.length} ${collection.items.length == 1 ? 'piece' : 'pieces'}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, collection),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) await _addLink(selected);
  }

  Future<void> _remove(
    FashionCollection collection,
    CollectionItem item,
  ) async {
    try {
      await widget.deleteItem(collection.id, item.id);
      if (!mounted) return;
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) => CompeteScreen(
    onSearch: widget.onSearch,
    onProfile: widget.onProfile,
    profileName: widget.profileName,
    profileAvatarUrl: widget.profileAvatarUrl,
    child: RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const _CollectionsLoading()
          : _error != null
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.65,
                  child: AppErrorState(message: _error!, onRetry: _load),
                ),
              ],
            )
          : ListView(
              key: const Key('collections-page'),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 84),
              children: [
                AppPageIntro(
                  eyebrow: 'Your wardrobe',
                  title: 'Collections',
                  subtitle:
                      'A visual library of everything you want to wear, try and post.',
                  trailing: IconButton.filled(
                    key: const Key('add-collection-button'),
                    onPressed: _createCollection,
                    tooltip: 'New collection',
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                AppReveal(
                  child: _WardrobeOverview(
                    collectionCount: _collections.length,
                    readyCount: _readyCount,
                    pieceCount: _pieceCount,
                    onQuickAdd: _quickAdd,
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                _CollectionFilters(
                  selected: _filter,
                  allCount: _collections.length,
                  readyCount: _readyCount,
                  emptyCount: _collections.length - _readyCount,
                  onSelected: (filter) => setState(() => _filter = filter),
                ),
                const SizedBox(height: AppSpacing.x3),
                if (_collections.isEmpty)
                  AppEmptyState(
                    icon: Icons.folder_copy_outlined,
                    title: 'Create your first collection',
                    message:
                        'Group products by category, occasion or whatever makes sense to you.',
                    action: FilledButton.icon(
                      onPressed: _createCollection,
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('New collection'),
                    ),
                  )
                else if (_visibleCollections.isEmpty)
                  _FilteredCollectionEmpty(filter: _filter)
                else
                  ..._visibleCollections.asMap().entries.map(
                    (entry) => AppReveal(
                      key: ValueKey('collection-${entry.value.id}'),
                      delay: Duration(
                        milliseconds: (entry.key * 30).clamp(0, 150),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                        child: _CollectionSection(
                          collection: entry.value,
                          busy: _busyCollectionId == entry.value.id,
                          onAdd: () => _addLink(entry.value),
                          onRemove: (item) => _remove(entry.value, item),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class _CollectionSection extends StatelessWidget {
  const _CollectionSection({
    required this.collection,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
  });

  final FashionCollection collection;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<CollectionItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final visual = _collectionVisual(collection.kind);
    final count = collection.items.length;
    return Container(
      key: Key('collection-card-${collection.id}'),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A191A17),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 8, 9),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: visual.color,
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Icon(visual.icon, size: 20),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visual.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sunken,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: Key('add-to-collection-${collection.id}'),
                  onPressed: busy ? null : onAdd,
                  tooltip: 'Add product link',
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded, size: 21),
                ),
              ],
            ),
          ),
          if (collection.items.isEmpty)
            _EmptyCollectionPrompt(
              collectionId: collection.id,
              visual: visual,
              busy: busy,
              onAdd: onAdd,
            )
          else
            SizedBox(
              height: 184,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 13),
                scrollDirection: Axis.horizontal,
                itemCount: collection.items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == collection.items.length) {
                    return _AddPieceCard(busy: busy, onTap: onAdd);
                  }
                  final item = collection.items[index];
                  return _CollectionItemCard(
                    item: item,
                    onRemove: () => onRemove(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CollectionItemCard extends StatelessWidget {
  const _CollectionItemCard({required this.item, required this.onRemove});
  final CollectionItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 118,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.photo,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: GarmentImage(
                  source: item.imageUrl,
                  semanticLabel: item.title,
                  cacheWidth: 280,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: IconButton.filledTonal(
                  onPressed: onRemove,
                  tooltip: 'Remove ${item.title}',
                  icon: const Icon(Icons.close_rounded, size: 13),
                  style: const ButtonStyle(
                    fixedSize: WidgetStatePropertyAll(Size.square(27)),
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          item.price?.isNotEmpty == true
              ? item.price!
              : item.brand?.isNotEmpty == true
              ? item.brand!
              : 'Saved piece',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}

class _WardrobeOverview extends StatelessWidget {
  const _WardrobeOverview({
    required this.collectionCount,
    required this.readyCount,
    required this.pieceCount,
    required this.onQuickAdd,
  });

  final int collectionCount;
  final int readyCount;
  final int pieceCount;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('wardrobe-overview'),
    padding: const EdgeInsets.all(AppSpacing.x4),
    decoration: BoxDecoration(
      color: AppColors.textPrimary,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'DIGITAL WARDROBE',
                style: TextStyle(
                  color: Color(0xFFBFC1B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            FilledButton.icon(
              key: const Key('quick-add-product-button'),
              onPressed: onQuickAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.fresh,
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 11),
              ),
              icon: const Icon(Icons.add_link_rounded, size: 16),
              label: const Text('Quick add'),
            ),
          ],
        ),
        Text(
          '$pieceCount',
          style: const TextStyle(
            color: AppColors.textOnAccent,
            fontSize: 38,
            height: 1,
            fontWeight: FontWeight.w500,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          pieceCount == 1 ? 'piece ready to style' : 'pieces ready to style',
          style: const TextStyle(color: Color(0xFFD4D5CF), fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.x4),
        Container(height: 1, color: const Color(0xFF363832)),
        const SizedBox(height: AppSpacing.x3),
        Row(
          children: [
            _WardrobeStat(value: collectionCount, label: 'collections'),
            const SizedBox(width: AppSpacing.x6),
            _WardrobeStat(value: readyCount, label: 'with pieces'),
            const Spacer(),
            const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppColors.fresh,
            ),
          ],
        ),
      ],
    ),
  );
}

class _WardrobeStat extends StatelessWidget {
  const _WardrobeStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '$value',
        style: const TextStyle(
          color: AppColors.textOnAccent,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(color: Color(0xFFACAEA5), fontSize: 11),
      ),
    ],
  );
}

class _CollectionFilters extends StatelessWidget {
  const _CollectionFilters({
    required this.selected,
    required this.allCount,
    required this.readyCount,
    required this.emptyCount,
    required this.onSelected,
  });

  final _CollectionFilter selected;
  final int allCount;
  final int readyCount;
  final int emptyCount;
  final ValueChanged<_CollectionFilter> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _CollectionFilterTile(
          key: const Key('collection-filter-all'),
          label: 'All',
          count: allCount,
          selected: selected == _CollectionFilter.all,
          onTap: () => onSelected(_CollectionFilter.all),
        ),
      ),
      const SizedBox(width: AppSpacing.x1),
      Expanded(
        child: _CollectionFilterTile(
          key: const Key('collection-filter-ready'),
          label: 'Ready',
          count: readyCount,
          selected: selected == _CollectionFilter.ready,
          onTap: () => onSelected(_CollectionFilter.ready),
        ),
      ),
      const SizedBox(width: AppSpacing.x1),
      Expanded(
        child: _CollectionFilterTile(
          key: const Key('collection-filter-empty'),
          label: 'Empty',
          count: emptyCount,
          selected: selected == _CollectionFilter.empty,
          onTap: () => onSelected(_CollectionFilter.empty),
        ),
      ),
    ],
  );
}

class _CollectionFilterTile extends StatelessWidget {
  const _CollectionFilterTile({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: AppMotion.standard,
        curve: AppMotion.curve,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.sunken,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? AppColors.textPrimary : AppColors.borderDefault,
          ),
        ),
        child: Text(
          '$label  $count',
          style: TextStyle(
            color: selected ? AppColors.textOnAccent : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _FilteredCollectionEmpty extends StatelessWidget {
  const _FilteredCollectionEmpty({required this.filter});

  final _CollectionFilter filter;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: filter == _CollectionFilter.ready
        ? Icons.bookmark_add_outlined
        : Icons.task_alt_rounded,
    title: filter == _CollectionFilter.ready
        ? 'Nothing saved yet'
        : 'Every collection has a start',
    message: filter == _CollectionFilter.ready
        ? 'Add a product link and this view will become your ready-to-style wardrobe.'
        : 'There are no empty collections right now. Nice work building your wardrobe.',
  );
}

class _EmptyCollectionPrompt extends StatelessWidget {
  const _EmptyCollectionPrompt({
    required this.collectionId,
    required this.visual,
    required this.busy,
    required this.onAdd,
  });

  final String collectionId;
  final _CollectionVisual visual;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 2, 12, 13),
    padding: const EdgeInsets.all(AppSpacing.x3),
    decoration: BoxDecoration(
      color: visual.color.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            visual.emptyMessage,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        OutlinedButton.icon(
          key: Key('empty-collection-add-$collectionId'),
          onPressed: busy ? null : onAdd,
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.raised,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add'),
        ),
      ],
    ),
  );
}

class _AddPieceCard extends StatelessWidget {
  const _AddPieceCard({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    child: Material(
      color: AppColors.sunken,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.raised,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, size: 19),
              ),
            const SizedBox(height: AppSpacing.x2),
            const Text(
              'Add piece',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CollectionVisual {
  const _CollectionVisual({
    required this.color,
    required this.icon,
    required this.subtitle,
    required this.emptyMessage,
  });

  final Color color;
  final IconData icon;
  final String subtitle;
  final String emptyMessage;
}

_CollectionVisual _collectionVisual(String kind) => switch (kind) {
  'tshirt' => const _CollectionVisual(
    color: Color(0xFFEAF5D4),
    icon: Icons.checkroom_outlined,
    subtitle: 'Everyday foundations',
    emptyMessage: 'Start with a tee you would wear on repeat.',
  ),
  'shirt' => const _CollectionVisual(
    color: Color(0xFFE3EFFD),
    icon: Icons.dry_cleaning_outlined,
    subtitle: 'Shirts, tops and layers',
    emptyMessage: 'Save a shirt or top for your next layered look.',
  ),
  'jeans' => const _CollectionVisual(
    color: Color(0xFFE9E7FA),
    icon: Icons.straighten,
    subtitle: 'Denim and bottoms',
    emptyMessage: 'Build your bottoms rotation with jeans or trousers.',
  ),
  'shoes' => const _CollectionVisual(
    color: Color(0xFFFFE9D8),
    icon: Icons.ice_skating_outlined,
    subtitle: 'Pairs that finish the fit',
    emptyMessage: 'Add the pair that completes your next outfit.',
  ),
  'dress' => const _CollectionVisual(
    color: Color(0xFFFFE7EF),
    icon: Icons.woman_2_outlined,
    subtitle: 'One-piece looks',
    emptyMessage: 'Keep a dress ready for a complete one-piece try-on.',
  ),
  'accessory' => const _CollectionVisual(
    color: Color(0xFFDFF4EF),
    icon: Icons.watch_outlined,
    subtitle: 'The finishing details',
    emptyMessage: 'Finish a look with eyewear, bags, hats or jewellery.',
  ),
  _ => const _CollectionVisual(
    color: AppColors.freshSoft,
    icon: Icons.folder_outlined,
    subtitle: 'Your personal edit',
    emptyMessage: 'Give this collection its first standout piece.',
  ),
};

class _CollectionsLoading extends StatelessWidget {
  const _CollectionsLoading();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
    children: [
      const AppLoadingField(
        child: SizedBox(height: 68, child: ColoredBox(color: AppColors.sunken)),
      ),
      const SizedBox(height: AppSpacing.x4),
      for (var index = 0; index < 3; index++) ...[
        const AppLoadingField(
          child: SizedBox(
            height: 176,
            child: ColoredBox(color: AppColors.sunken),
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
      ],
    ],
  );
}
