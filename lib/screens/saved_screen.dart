import 'package:flutter/material.dart';

import '../components/screen.dart';
import '../components/garment_image.dart';
import '../models/closet_item.dart';
import '../theme/app_theme.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key, required this.onSearch, this.items = const []});

  final VoidCallback onSearch;
  final List<ClosetItem> items;

  @override
  Widget build(BuildContext context) {
    return CompeteScreen(
      onSearch: onSearch,
      child: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.x8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nothing saved',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.x2),
                    Text(
                      'Looks you save will collect here, ready to pair.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              key: const Key('saved-items-grid'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.76,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _SavedItemCard(item: items[index]),
            ),
    );
  }
}

class _SavedItemCard extends StatelessWidget {
  const _SavedItemCard({required this.item});

  final ClosetItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.photo,
              borderRadius: BorderRadius.circular(AppRadii.large),
              border: Border.all(color: AppColors.borderDefault, width: 0.5),
            ),
            child: GarmentImage(source: item.image, semanticLabel: item.title),
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        if (item.brand != null)
          Text(
            item.brand!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
      ],
    );
  }
}
