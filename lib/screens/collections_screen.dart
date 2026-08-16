import 'package:flutter/material.dart';

import '../components/garment_image.dart';
import '../components/screen.dart';
import '../models/fashion_collection.dart';
import '../services/collection_service.dart';
import '../services/ingest_service.dart';
import '../theme/app_theme.dart';

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

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<FashionCollection> _collections = const [];
  bool _loading = true;
  String? _busyCollectionId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final collections = await widget.fetchCollections();
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
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
        content: TextField(
          key: const Key('collection-product-link'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'Paste a fashion product URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Fetch'),
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
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.65,
                  child: _CollectionsError(message: _error!, onRetry: _load),
                ),
              ],
            )
          : ListView(
              key: const Key('collections-page'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 108),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Collections',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: AppSpacing.x1),
                          Text(
                            'Save pieces by category, then mix them into a complete look.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    IconButton.filled(
                      key: const Key('add-collection-button'),
                      onPressed: _createCollection,
                      tooltip: 'New collection',
                      icon: const Icon(Icons.create_new_folder_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x4),
                ..._collections.map(
                  (collection) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x4),
                    child: _CollectionSection(
                      collection: collection,
                      busy: _busyCollectionId == collection.id,
                      onAdd: () => _addLink(collection),
                      onRemove: (item) => _remove(collection, item),
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.raised,
      borderRadius: BorderRadius.circular(AppRadii.large),
      border: Border.all(color: AppColors.borderDefault),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          child: Row(
            children: [
              Icon(_collectionIcon(collection.kind), size: 20),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  collection.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${collection.items.length}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              IconButton(
                key: Key('add-to-collection-${collection.id}'),
                onPressed: busy ? null : onAdd,
                tooltip: 'Add product link',
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_link, size: 20),
              ),
            ],
          ),
        ),
        if (collection.items.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 4, 14, 16),
            child: Text(
              'Share a product here or paste its buying link.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          )
        else
          SizedBox(
            height: 174,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
              scrollDirection: Axis.horizontal,
              itemCount: collection.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
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

class _CollectionItemCard extends StatelessWidget {
  const _CollectionItemCard({required this.item, required this.onRemove});
  final CollectionItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 116,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.photo,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: GarmentImage(
                  source: item.imageUrl,
                  semanticLabel: item.title,
                ),
              ),
              Positioned(
                right: 3,
                top: 3,
                child: IconButton.filledTonal(
                  onPressed: onRemove,
                  tooltip: 'Remove ${item.title}',
                  icon: const Icon(Icons.close, size: 14),
                  style: const ButtonStyle(
                    fixedSize: WidgetStatePropertyAll(Size.square(28)),
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
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        if (item.price != null)
          Text(
            item.price!,
            maxLines: 1,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
      ],
    ),
  );
}

IconData _collectionIcon(String kind) => switch (kind) {
  'tshirt' => Icons.checkroom_outlined,
  'shirt' => Icons.dry_cleaning_outlined,
  'jeans' => Icons.straighten,
  'shoes' => Icons.ice_skating_outlined,
  'dress' => Icons.woman_2_outlined,
  'accessory' => Icons.watch_outlined,
  _ => Icons.folder_outlined,
};

class _CollectionsError extends StatelessWidget {
  const _CollectionsError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.x3),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
