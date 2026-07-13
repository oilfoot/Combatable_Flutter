import 'dart:async';

import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../controllers/library_controller.dart';
import '../widgets/animation/animation_card.dart';
import '../widgets/animation/animation_card_flight.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/animation/animation_preview_frame.dart';

class LibrarySearchScreen extends StatefulWidget {
  const LibrarySearchScreen({
    super.key,
    required this.libraryController,
    required this.sequenceBuilderNavKey,
  });

  final LibraryController libraryController;
  final GlobalKey sequenceBuilderNavKey;

  @override
  State<LibrarySearchScreen> createState() => _LibrarySearchScreenState();
}

class _LibrarySearchScreenState extends State<LibrarySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _query = '';
  bool _isLoadingCategories = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    widget.libraryController.addListener(_onLibraryChanged);
    _loadSearchData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.libraryController.removeListener(_onLibraryChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSearchData() async {
    setState(() {
      _isLoadingCategories = true;
      _loadError = null;
    });

    try {
      await widget.libraryController.loadAllCategories();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  List<LibraryDisplayItem> get _filteredItems {
    final normalizedQuery = _query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return widget.libraryController.allItems;
    }

    return widget.libraryController.allItems.where((entry) {
      final item = entry.item;
      final searchable = <String>[
        item.title,
        item.animationName,
        item.startPosition,
        item.endPosition,
        item.category ?? '',
        ...item.tags,
      ].join(' ').toLowerCase();

      return searchable.contains(normalizedQuery);
    }).toList();
  }

  Future<void> _showAnimationInfo(LibraryDisplayItem entry) async {
    await AnimationInfoSheet.show(
      context,
      item: entry.item,
      isDownloaded: entry.isInstalled,
      isDownloading: entry.isDownloading,
      buttonText: widget.libraryController.getPrimaryActionLabel(entry),
      resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
      resolveCachedPreviewPath: widget.libraryController.getCachedPreviewPath,
      onAnimatedPrimaryAction: (sourceKey) => AnimationCardFlight.run(
        sourceKey: sourceKey,
        targetKey: widget.sequenceBuilderNavKey,
        finalScale: AnimationCardFlightTuning.fullLibraryFinalScale,
        flightSize: const Size.square(AnimationCard.compactExtent),
        action: () => _handlePrimaryAction(entry),
      ),
      onPrimaryAction: () => _handlePrimaryAction(entry),
    );
  }

  Future<void> _handlePrimaryAction(LibraryDisplayItem entry) async {
    try {
      await widget.libraryController.performPrimaryAction(entry);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add ${entry.item.title}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filteredItems;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back_ios_new,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Suchen',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search animations...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                ),
                onChanged: (value) {
                  setState(() => _query = value);
                },
              ),
            ),
            if (_isLoadingCategories)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Could not load all categories: $_loadError',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        _query.trim().isEmpty
                            ? 'Start typing to search animations'
                            : 'No animations found',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        AppShell.floatingNavExtraScrollSpace,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final entry = items[index];
                        return _SearchResultTile(
                          entry: entry,
                          resolvePreviewPath:
                              widget.libraryController.getOrDownloadPreview,
                          onTap: () => _showAnimationInfo(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.entry,
    required this.resolvePreviewPath,
    required this.onTap,
  });

  final LibraryDisplayItem entry;
  final Future<String?> Function(String? previewPath) resolvePreviewPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: AnimationPreviewFrame(
              previewPath: item.previewPath,
              resolvePreviewPath: resolvePreviewPath,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitleText(itemTags: item.tags, category: item.category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  String _subtitleText({
    required List<String> itemTags,
    required String? category,
  }) {
    final parts = <String>[
      if (category != null && category.trim().isNotEmpty) category,
      ...itemTags,
    ];

    return parts.join(' · ');
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.22),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon),
      ),
    );
  }
}
