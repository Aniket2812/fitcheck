import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _query.trim();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x2,
                AppSpacing.x1,
                AppSpacing.x3,
                AppSpacing.x1,
              ),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('close-search-button'),
                    onPressed: widget.onClose,
                    tooltip: 'Close search',
                    icon: const Icon(Icons.arrow_back, size: 22),
                    color: AppColors.textPrimary,
                    style: const ButtonStyle(
                      fixedSize: WidgetStatePropertyAll(
                        Size.square(AppSizes.hitTarget),
                      ),
                      padding: WidgetStatePropertyAll(EdgeInsets.zero),
                      overlayColor: WidgetStatePropertyAll(Colors.transparent),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.raised,
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        border: Border.all(
                          color: AppColors.borderDefault,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.x2),
                          Expanded(
                            child: TextField(
                              key: const Key('search-field'),
                              controller: _controller,
                              autofocus: true,
                              textCapitalization: TextCapitalization.none,
                              textInputAction: TextInputAction.search,
                              autocorrect: false,
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration.collapsed(
                                hintText: 'Search looks, pieces, people',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                          if (trimmed.isNotEmpty)
                            IconButton(
                              key: const Key('clear-search-button'),
                              onPressed: _clear,
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close, size: 18),
                              color: AppColors.textMuted,
                              style: const ButtonStyle(
                                minimumSize: WidgetStatePropertyAll(
                                  Size.square(32),
                                ),
                                fixedSize: WidgetStatePropertyAll(
                                  Size.square(32),
                                ),
                                padding: WidgetStatePropertyAll(
                                  EdgeInsets.zero,
                                ),
                                overlayColor: WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AnimatedScale(
              scale: trimmed.isEmpty ? 1 : 0.985,
              duration: AppMotion.standard,
              curve: AppMotion.curve,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.freshSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          trimmed.isEmpty
                              ? Icons.search_rounded
                              : Icons.manage_search_rounded,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      Text(
                        trimmed.isEmpty ? 'Search Compete' : 'No results',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        trimmed.isEmpty
                            ? 'Find looks by piece, brand, or the person who put them together.'
                            : 'Nothing matches “$trimmed” yet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppColors.textSecondary,
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
    );
  }
}
