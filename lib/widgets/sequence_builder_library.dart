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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final height = isExpanded
        ? screenHeight * 0.76
        : 128.0 + AppShell.floatingNavExtraScrollSpace;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: height,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        6,
        16,
        10 + AppShell.floatingNavExtraScrollSpace,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF2141418),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.12))),
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
          Center(
            child: GestureDetector(
              onTap: onToggleExpanded,
              onVerticalDragUpdate: (details) {
                final delta = details.primaryDelta;
                if (delta == null) return;

                if (!isExpanded && delta < -6) onToggleExpanded();
                if (isExpanded && delta > 6) onToggleExpanded();
              },
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Library',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                onPressed: onToggleExpanded,
                icon: Icon(isExpanded ? Icons.close : Icons.keyboard_arrow_up),
              ),
            ],
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
                : isExpanded
                ? GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final entry = items[index];

                      return _SequenceLibraryMiniCard(
                        entry: entry,
                        libraryController: libraryController,
                        onTap: () => onItemTap(entry),
                        onPrimaryAction: () => onPrimaryAction(entry),
                      );
                    },
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final entry = items[index];

                      return SizedBox(
                        width: 104,
                        child: _SequenceLibraryMiniCard(
                          entry: entry,
                          libraryController: libraryController,
                          onTap: () => onItemTap(entry),
                          onPrimaryAction: () => onPrimaryAction(entry),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SequenceLibraryMiniCard extends StatelessWidget {
  const _SequenceLibraryMiniCard({
    required this.entry,
    required this.libraryController,
    required this.onTap,
    required this.onPrimaryAction,
  });

  final LibraryDisplayItem entry;
  final LibraryController libraryController;
  final VoidCallback onTap;
  final Future<void> Function() onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;

    return Material(
      color: Colors.white.withOpacity(0.045),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
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
