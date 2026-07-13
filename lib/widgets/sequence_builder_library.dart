import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../controllers/library_controller.dart';
import 'animation/animation_card.dart';

class SequenceBuilderLibrary extends StatelessWidget {
  const SequenceBuilderLibrary({
    super.key,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.items,
    required this.libraryController,
    required this.onItemTap,
    required this.onPrimaryAction,
  });

  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final List<LibraryDisplayItem> items;
  final LibraryController libraryController;
  final Future<void> Function(LibraryDisplayItem entry) onItemTap;
  final Future<void> Function(LibraryDisplayItem entry) onPrimaryAction;

  static const double collapsedHeight = 264;
  static const double expandedHeightFactor = 0.85;
  static const double animationCardExtent = 112;
  static const double collapsedGridHeight = animationCardExtent + 4;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final height = isExpanded
        ? screenHeight * expandedHeightFactor
        : collapsedHeight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isExpanded ? null : onToggleExpanded,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;

        if (!isExpanded && velocity < -150) {
          onToggleExpanded();
        } else if (isExpanded && velocity > 150) {
          onToggleExpanded();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        height: height,
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 6, 16, isExpanded ? 12 : 92),
        decoration: BoxDecoration(
          color: const Color(0xF2141418),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleExpanded,
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Library',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No valid next animations available',
                        style: TextStyle(color: Colors.white.withOpacity(0.62)),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final gridHeight = isExpanded
                            ? constraints.maxHeight
                            : collapsedGridHeight;

                        return Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: double.infinity,
                            height: gridHeight,
                            child: GridView.builder(
                              padding: const EdgeInsets.only(
                                bottom: AppShell.floatingNavExtraScrollSpace,
                              ),
                              physics: isExpanded
                                  ? const BouncingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    mainAxisExtent: animationCardExtent,
                                  ),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final entry = items[index];
                                final card = AnimationCard.compact(
                                  key: ValueKey(entry.item.animationName),
                                  item: entry.item,
                                  isDownloading: entry.isDownloading,
                                  resolvePreviewPath:
                                      libraryController.getOrDownloadPreview,
                                  resolveCachedPreviewPath:
                                      libraryController.getCachedPreviewPath,
                                  onPrimaryAction: () => onPrimaryAction(entry),
                                  onInfoTap: () => onItemTap(entry),
                                );

                                if (index < 3) return card;

                                return TweenAnimationBuilder<double>(
                                  key: ValueKey(
                                    'reveal-${entry.item.animationName}',
                                  ),
                                  tween: Tween<double>(
                                    begin: 0,
                                    end: isExpanded ? 1 : 0,
                                  ),
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  child: card,
                                  builder: (context, opacity, child) {
                                    return Opacity(
                                      opacity: opacity,
                                      child: child,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
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
