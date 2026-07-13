import 'dart:async';

import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../controllers/library_controller.dart';
import 'library_search_screen.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/animation/animation_card.dart';

class FullLibraryScreen extends StatefulWidget {
  const FullLibraryScreen({super.key, required this.libraryController});

  final LibraryController libraryController;

  @override
  State<FullLibraryScreen> createState() => _FullLibraryScreenState();
}

class _FullLibraryScreenState extends State<FullLibraryScreen> {
  @override
  void initState() {
    super.initState();
    widget.libraryController.addListener(_onLibraryChanged);
  }

  @override
  void dispose() {
    widget.libraryController.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) setState(() {});
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
      onPrimaryAction: () async {
        try {
          await widget.libraryController.performPrimaryAction(entry);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add ${entry.item.title}: $e')),
          );
        }
      },
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
    final library = widget.libraryController;
    final theme = Theme.of(context);
    final items = library.categoryFilteredItems;

    return Scaffold(
      body: Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              12,
              200,
              12,
              AppShell.floatingNavExtraScrollSpace,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.62,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final entry = items[index];

              return AnimationCard.standard(
                width: double.infinity,
                item: entry.item,
                isDownloaded: entry.isInstalled,
                isDownloading: entry.isDownloading,
                actionLabel: library.getPrimaryActionLabel(entry),
                resolvePreviewPath: library.getOrDownloadPreview,
                resolveCachedPreviewPath: library.getCachedPreviewPath,
                onTap: () => _showAnimationInfo(entry),
                onPrimaryAction: () => _handlePrimaryAction(entry),
              );
            },
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 18,
                left: 16,
                right: 16,
                bottom: 18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.scaffoldBackgroundColor,
                    theme.scaffoldBackgroundColor.withOpacity(0.92),
                    theme.scaffoldBackgroundColor.withOpacity(0),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Bibliothek',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LibrarySearchScreen(
                                libraryController: library,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryPill(
                          label: 'Alle',
                          selected: library.selectedCategoryId == null,
                          onTap: () {
                            unawaited(library.selectCategory(null));
                          },
                        ),
                        ...library.categories.map(
                          (category) => _CategoryPill(
                            label: category.displayName,
                            selected: library.selectedCategoryId == category.id,
                            onTap: () {
                              unawaited(library.selectCategory(category.id));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withOpacity(0.88)
                : Colors.black.withOpacity(0.34),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Colors.white.withOpacity(0.7)
                  : Colors.white.withOpacity(0.14),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
