import 'package:flutter/material.dart';

import '../../controllers/library_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/profile_layout.dart';
import '../animation/animation_card.dart';

class ProfileFavoritesGrid extends StatelessWidget {
  const ProfileFavoritesGrid({
    super.key,
    required this.entries,
    required this.resolvePreviewPath,
    required this.resolveCachedPreviewPath,
    required this.onEntryPressed,
    required this.onPrimaryAction,
    required this.onRemoveBookmark,
  });

  final List<LibraryDisplayItem> entries;
  final Future<String?> Function(String? previewPath) resolvePreviewPath;
  final String? Function(String? previewPath) resolveCachedPreviewPath;
  final ValueChanged<LibraryDisplayItem> onEntryPressed;
  final Future<void> Function(LibraryDisplayItem entry) onPrimaryAction;
  final Future<void> Function(LibraryDisplayItem entry) onRemoveBookmark;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ProfileLayout.favoriteGridColumns,
        mainAxisSpacing: ProfileLayout.favoriteGridSpacing,
        crossAxisSpacing: ProfileLayout.favoriteGridSpacing,
        childAspectRatio: ProfileLayout.favoriteCardAspectRatio,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return AnimationCard.standard(
          key: ValueKey('favorite-${entry.item.animationName}'),
          width: double.infinity,
          item: entry.item,
          isDownloaded: entry.isInstalled,
          isDownloading: entry.isDownloading,
          actionLabel: entry.isDownloading
              ? 'Downloading...'
              : entry.isRemote && !entry.isInstalled
              ? 'Download'
              : 'Add',
          showPrimaryAction: false,
          borderRadius: AppRadii.card,
          isBookmarked: true,
          resolvePreviewPath: resolvePreviewPath,
          resolveCachedPreviewPath: resolveCachedPreviewPath,
          onTap: () => onEntryPressed(entry),
          onPrimaryAction: () => onPrimaryAction(entry),
          onBookmarkTap: () => onRemoveBookmark(entry),
        );
      },
    );
  }
}
