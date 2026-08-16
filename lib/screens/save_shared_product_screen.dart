import 'package:flutter/material.dart';

import '../models/closet_item.dart';
import '../models/fashion_collection.dart';
import '../services/collection_service.dart';
import '../services/ingest_service.dart';
import '../theme/app_theme.dart';

class SaveSharedProductScreen extends StatefulWidget {
  const SaveSharedProductScreen({
    super.key,
    required this.productUrl,
    this.fetchCollections = CollectionService.fetchCollections,
    this.ingestLink = IngestService.ingest,
    this.saveItem = CollectionService.addItem,
  });

  final String productUrl;
  final FetchCollections fetchCollections;
  final IngestLink ingestLink;
  final SaveCollectionItem saveItem;

  @override
  State<SaveSharedProductScreen> createState() =>
      _SaveSharedProductScreenState();
}

class _SaveSharedProductScreenState extends State<SaveSharedProductScreen> {
  List<FashionCollection> _collections = const [];
  bool _loading = true;
  String? _savingId;
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save(FashionCollection collection) async {
    setState(() {
      _savingId = collection.id;
      _error = null;
    });
    try {
      final ClosetItem product = await widget.ingestLink(widget.productUrl);
      final item = await widget.saveItem(collection.id, product);
      if (mounted) Navigator.pop(context, item);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingId = null;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('save-shared-product-screen'),
    backgroundColor: AppColors.canvas,
    appBar: AppBar(
      title: const Text('Save shared item'),
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const Text(
                'Choose a collection',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.x2),
              const Text(
                'We’ll fetch the product, cut it out, and keep its original buying link.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x3),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFF8B5751)),
                  ),
                ),
              const SizedBox(height: AppSpacing.x4),
              ..._collections.map(
                (collection) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                  child: ListTile(
                    key: Key('share-collection-${collection.id}'),
                    onTap: _savingId == null ? () => _save(collection) : null,
                    tileColor: AppColors.raised,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: AppColors.borderDefault),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.sunken,
                      child: Icon(_collectionIcon(collection.kind), size: 20),
                    ),
                    title: Text(
                      collection.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${collection.items.length} ${collection.items.length == 1 ? 'item' : 'items'}',
                    ),
                    trailing: _savingId == collection.id
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
            ],
          ),
  );
}

IconData _collectionIcon(String kind) => switch (kind) {
  'tshirt' || 'shirt' => Icons.checkroom_outlined,
  'jeans' => Icons.straighten,
  'shoes' => Icons.ice_skating_outlined,
  'dress' => Icons.woman_2_outlined,
  'accessory' => Icons.watch_outlined,
  _ => Icons.folder_outlined,
};
