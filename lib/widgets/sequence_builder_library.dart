import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../controllers/library_controller.dart';
import '../widgets/animation/animation_preview_frame.dart';

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
                                final card = _SequenceLibraryMiniCard(
                                  key: ValueKey(entry.item.animationName),
                                  entry: entry,
                                  libraryController: libraryController,
                                  onTap: () => onPrimaryAction(entry),
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

class _SequenceLibraryMiniCard extends StatelessWidget {
  const _SequenceLibraryMiniCard({
    super.key,
    required this.entry,
    required this.libraryController,
    required this.onTap,
    required this.onInfoTap,
  });

  final LibraryDisplayItem entry;
  final LibraryController libraryController;
  final Future<void> Function() onTap;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;

    return Material(
      color: Colors.white.withOpacity(0.045),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: entry.isDownloading
            ? null
            : () async {
                await onTap();
              },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimationPreviewFrame(
                previewPath: item.previewPath,
                resolvePreviewPath: libraryController.getOrDownloadPreview,
                resolveCachedPreviewPath:
                    libraryController.getCachedPreviewPath,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x20000000),
                      Color(0xB8000000),
                    ],
                    stops: [0.40, 0.70, 1.0],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: GestureDetector(
                  onTap: onInfoTap,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.34),
                      border: Border.all(color: Colors.white.withOpacity(0.16)),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.02,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
