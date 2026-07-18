import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_shell.dart';
import '../controllers/library_controller.dart';
import '../theme/app_theme.dart';
import '../theme/profile_layout.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/app_confirmation_dialog.dart';
import '../widgets/profile/profile_collection_tabs.dart';
import '../widgets/profile/profile_favorites_grid.dart';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/profile_sequence_list.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.libraryController});

  final LibraryController libraryController;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileCollection _selectedCollection = ProfileCollection.favorites;

  // Temporary presentation data. These entries will be replaced by the saved
  // sequence repository when persistence is introduced.
  static const _sequences = <ProfileSequenceEntry>[
    ProfileSequenceEntry(
      title: 'Kick Combo',
      stepCount: 8,
      startPosition: 'Pos3',
      endPosition: 'Pos2',
      updatedLabel: 'Edited 2 hours ago',
    ),
    ProfileSequenceEntry(
      title: 'Defense Flow',
      stepCount: 6,
      startPosition: 'Pos0',
      endPosition: 'Pos3',
      updatedLabel: 'Edited yesterday',
    ),
    ProfileSequenceEntry(
      title: 'Warm-up',
      stepCount: 5,
      startPosition: 'Any',
      endPosition: 'Pos1',
      updatedLabel: 'Edited 3 days ago',
    ),
  ];

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

  void _selectCollection(ProfileCollection collection) {
    if (_selectedCollection == collection) return;
    setState(() => _selectedCollection = collection);
  }

  void _showPlaceholder(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature will be connected in the next step.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.elevatedSurface,
        ),
      );
  }

  Future<void> _showAnimationInfo(LibraryDisplayItem entry) async {
    final library = widget.libraryController;
    await AnimationInfoSheet.show(
      context,
      item: entry.item,
      isDownloaded: entry.isInstalled,
      isDownloading: entry.isDownloading,
      buttonText: library.getPrimaryActionLabel(entry),
      resolvePreviewPath: library.getOrDownloadPreview,
      resolveCachedPreviewPath: library.getCachedPreviewPath,
      isBookmarked: library.isBookmarked(entry.item),
      onBookmarkToggle: () => library.toggleBookmark(entry.item),
      onPrimaryAction: () => library.performPrimaryAction(entry),
    );
  }

  Future<void> _removeBookmarkWithConfirmation(LibraryDisplayItem entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.black.withValues(alpha: AppOpacity.barrier),
      builder: (_) => AppConfirmationDialog(
        title: 'Remove bookmark?',
        message: 'Remove ${entry.item.title} from Favorites?',
        confirmLabel: 'Remove',
        icon: Icons.bookmark_remove_outlined,
      ),
    );

    if (confirmed != true || !mounted) return;
    await HapticFeedback.selectionClick();
    await widget.libraryController.toggleBookmark(entry.item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ProfileLayout.pagePadding,
                AppSpacing.xxl,
                ProfileLayout.pagePadding,
                0,
              ),
              sliver: SliverList.list(
                children: [
                  ProfileHeader(
                    onSettingsPressed: () =>
                        _showPlaceholder('Account and settings'),
                  ),
                  const SizedBox(height: AppSpacing.panel),
                  ProfileCollectionTabs(
                    selectedCollection: _selectedCollection,
                    onSelected: _selectCollection,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: ProfileLayout.pagePadding,
              ),
              sliver: SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: AppMotion.quick,
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  child: _selectedCollection == ProfileCollection.favorites
                      ? ProfileFavoritesGrid(
                          key: ValueKey(ProfileCollection.favorites),
                          entries: widget.libraryController.bookmarkedItems,
                          resolvePreviewPath:
                              widget.libraryController.getOrDownloadPreview,
                          resolveCachedPreviewPath:
                              widget.libraryController.getCachedPreviewPath,
                          onEntryPressed: _showAnimationInfo,
                          onPrimaryAction:
                              widget.libraryController.performPrimaryAction,
                          onRemoveBookmark: _removeBookmarkWithConfirmation,
                        )
                      : ProfileSequenceList(
                          key: const ValueKey(ProfileCollection.sequences),
                          entries: _sequences,
                          onSequencePressed: (entry) =>
                              _showPlaceholder(entry.title),
                        ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppShell.floatingNavExtraScrollSpace),
            ),
          ],
        ),
      ),
    );
  }
}
