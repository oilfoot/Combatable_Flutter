import 'package:flutter/material.dart';

import '../../controllers/library_controller.dart';
import '../../theme/app_theme.dart';
import '../animation/animation_card.dart';

class SequenceBuilderLibraryExpandedContent extends StatefulWidget {
  const SequenceBuilderLibraryExpandedContent({
    super.key,
    required this.items,
    required this.libraryController,
    required this.onItemTap,
    required this.onPrimaryAction,
    required this.bottomPadding,
    this.placeholderCount = 0,
  });

  final List<LibraryDisplayItem> items;
  final LibraryController libraryController;
  final Future<void> Function(LibraryDisplayItem entry) onItemTap;
  final Future<void> Function(GlobalKey sourceKey, LibraryDisplayItem entry)
  onPrimaryAction;
  final double bottomPadding;
  final int placeholderCount;

  @override
  State<SequenceBuilderLibraryExpandedContent> createState() =>
      _SequenceBuilderLibraryExpandedContentState();
}

class _SequenceBuilderLibraryExpandedContentState
    extends State<SequenceBuilderLibraryExpandedContent> {
  static const _bookmarksId = '__bookmarks__';
  static const _allId = '__all__';

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _focusedSectionId;
  bool _transitionForward = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LibraryDisplayItem> get _searchedItems {
    if (_query.isEmpty) return widget.items;
    return widget.items
        .where((entry) => widget.libraryController.matchesSearch(entry, _query))
        .toList(growable: false);
  }

  List<_CompactLibrarySection> _sectionsFor(
    List<LibraryDisplayItem> matchingItems,
  ) {
    final sections = <_CompactLibrarySection>[];
    final visibleItemSets = <String>{};

    void addSection(_CompactLibrarySection section) {
      // One compatible animation may belong to Bookmarks, All matching, and
      // its manifest category. Avoid showing duplicate shelves when their
      // complete result sets are identical.
      final animationNames =
          section.items
              .map((entry) => entry.item.animationName)
              .toList(growable: false)
            ..sort();
      if (!visibleItemSets.add(animationNames.join('|'))) return;
      sections.add(section);
    }

    final bookmarked = matchingItems
        .where((entry) => widget.libraryController.isBookmarked(entry.item))
        .toList(growable: false);

    if (bookmarked.isNotEmpty) {
      addSection(
        _CompactLibrarySection(
          id: _bookmarksId,
          title: 'Bookmarks',
          icon: Icons.bookmark_rounded,
          items: bookmarked,
        ),
      );
    }

    if (matchingItems.isNotEmpty) {
      addSection(
        _CompactLibrarySection(
          id: _allId,
          title: 'All matching',
          items: matchingItems,
        ),
      );
    }

    for (final category in widget.libraryController.categories) {
      final categoryItems = matchingItems
          .where(
            (entry) =>
                entry.item.category?.toLowerCase() == category.id.toLowerCase(),
          )
          .toList(growable: false);
      if (categoryItems.isEmpty) continue;
      addSection(
        _CompactLibrarySection(
          id: category.id,
          title: category.displayName,
          items: categoryItems,
        ),
      );
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final searchedItems = _searchedItems;
    final sections = _sectionsFor(searchedItems);
    final focusedSection = _focusedSectionId == null
        ? null
        : sections
              .where((section) => section.id == _focusedSectionId)
              .firstOrNull;

    final Widget activeContent;
    final Key activeContentKey;

    if (widget.items.isEmpty && widget.placeholderCount > 0) {
      activeContentKey = const ValueKey('loading');
      activeContent = _LoadingGrid(
        count: widget.placeholderCount,
        bottomPadding: widget.bottomPadding,
      );
    } else if (_query.isNotEmpty) {
      activeContentKey = const ValueKey('search-results');
      activeContent = _CompactLibraryGrid(
        title: 'Search results',
        items: searchedItems,
        bottomPadding: widget.bottomPadding,
        cardBuilder: _buildCard,
      );
    } else if (focusedSection != null) {
      activeContentKey = ValueKey('section-${focusedSection.id}');
      activeContent = _CompactLibraryGrid(
        title: focusedSection.title,
        items: focusedSection.items,
        bottomPadding: widget.bottomPadding,
        onBack: () => setState(() {
          _transitionForward = false;
          _focusedSectionId = null;
        }),
        cardBuilder: _buildCard,
      );
    } else if (sections.isEmpty) {
      activeContentKey = const ValueKey('empty');
      activeContent = const _NoCompatibleAnimations();
    } else {
      activeContentKey = const ValueKey('category-shelves');
      activeContent = ListView.separated(
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        physics: const BouncingScrollPhysics(),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
        itemBuilder: (context, index) {
          final section = sections[index];
          return _CompactLibraryShelf(
            section: section,
            onViewAll: () => setState(() {
              _transitionForward = true;
              _focusedSectionId = section.id;
            }),
            cardBuilder: _buildCard,
          );
        },
      );
    }

    return Column(
      children: [
        _CompactLibrarySearchField(
          controller: _searchController,
          onChanged: (value) {
            final nextQuery = value.trim();
            setState(() {
              _transitionForward = nextQuery.isNotEmpty;
              _query = nextQuery;
              _focusedSectionId = null;
            });
          },
          onClear: () {
            _searchController.clear();
            setState(() {
              _transitionForward = false;
              _query = '';
              _focusedSectionId = null;
            });
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: AppMotion.standard,
              switchInCurve: AppMotion.emphasized,
              switchOutCurve: AppMotion.emphasized,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [...previousChildren, ?currentChild],
              ),
              transitionBuilder: (child, animation) {
                final isIncoming = child.key == activeContentKey;
                final horizontalOffset = _transitionForward ? 0.14 : -0.14;
                final begin = isIncoming
                    ? Offset(horizontalOffset, 0)
                    : Offset(-horizontalOffset * 0.7, 0);
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: AppMotion.emphasized,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: begin,
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(key: activeContentKey, child: activeContent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(LibraryDisplayItem entry) {
    final flightKey = GlobalKey(
      debugLabel: 'builder-expanded-card-${entry.item.animationName}',
    );
    return AnimationCard.compact(
      key: ValueKey(entry.item.animationName),
      flightKey: flightKey,
      item: entry.item,
      isDownloaded: entry.isInstalled,
      isDownloading: entry.isDownloading,
      resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
      resolveCachedPreviewPath: widget.libraryController.getCachedPreviewPath,
      onPrimaryAction: () => widget.onPrimaryAction(flightKey, entry),
      onInfoTap: () => widget.onItemTap(entry),
    );
  }
}

class _CompactLibrarySearchField extends StatelessWidget {
  const _CompactLibrarySearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textInputAction: TextInputAction.search,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: 'Search matching animations...',
          hintStyle: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            borderSide: const BorderSide(color: AppColors.borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            borderSide: const BorderSide(color: AppColors.accentSoft),
          ),
        ),
      ),
    );
  }
}

class _CompactLibrarySection {
  const _CompactLibrarySection({
    required this.id,
    required this.title,
    required this.items,
    this.icon,
  });

  final String id;
  final String title;
  final IconData? icon;
  final List<LibraryDisplayItem> items;
}

class _CompactLibraryShelf extends StatelessWidget {
  const _CompactLibraryShelf({
    required this.section,
    required this.onViewAll,
    required this.cardBuilder,
  });

  final _CompactLibrarySection section;
  final VoidCallback onViewAll;
  final Widget Function(LibraryDisplayItem entry) cardBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              child: section.icon == null
                  ? null
                  : Icon(section.icon, size: 17, color: AppColors.accentSoft),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(section.title, style: AppTypography.componentTitle),
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'View all',
                style: AppTypography.label.copyWith(
                  color: AppColors.accentSoft,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - AppSpacing.md * 2) / 3;
            return SizedBox(
              height: AnimationCard.compactExtent,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: section.items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) => SizedBox(
                  width: cardWidth,
                  height: AnimationCard.compactExtent,
                  child: cardBuilder(section.items[index]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CompactLibraryGrid extends StatelessWidget {
  const _CompactLibraryGrid({
    required this.title,
    required this.items,
    required this.bottomPadding,
    required this.cardBuilder,
    this.onBack,
  });

  final String title;
  final List<LibraryDisplayItem> items;
  final double bottomPadding;
  final Widget Function(LibraryDisplayItem entry) cardBuilder;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _NoSearchResults();
    }

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 32,
              child: onBack == null
                  ? null
                  : IconButton(
                      tooltip: 'Back to categories',
                      visualDensity: VisualDensity.compact,
                      onPressed: onBack,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 20,
                        height: 32,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, style: AppTypography.componentTitle)),
            Text(
              '${items.length}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.only(bottom: bottomPadding),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              mainAxisExtent: AnimationCard.compactExtent,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => cardBuilder(items[index]),
          ),
        ),
      ],
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid({required this.count, required this.bottomPadding});

  final int count;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.only(bottom: bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        mainAxisExtent: AnimationCard.compactExtent,
      ),
      itemCount: count,
      itemBuilder: (_, _) => const AnimationCardSkeleton.compact(),
    );
  }
}

class _NoCompatibleAnimations extends StatelessWidget {
  const _NoCompatibleAnimations();

  @override
  Widget build(BuildContext context) {
    return const _CompactEmptyMessage(
      icon: Icons.search_off_rounded,
      title: 'No matching animations',
      message: 'No animation can continue from the current position.',
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return const _CompactEmptyMessage(
      icon: Icons.manage_search_rounded,
      title: 'Nothing found',
      message: 'Try a different search.',
    );
  }
}

class _CompactEmptyMessage extends StatelessWidget {
  const _CompactEmptyMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentSoft),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTypography.componentTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
