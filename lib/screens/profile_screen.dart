import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_shell.dart';
import '../controllers/library_controller.dart';
import '../controllers/profile_preferences_controller.dart';
import '../controllers/saved_sequence_controller.dart';
import '../models/saved_sequence.dart';
import '../theme/app_theme.dart';
import '../theme/profile_layout.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/animation/animation_card_flight.dart';
import '../widgets/animation/animation_preview_frame.dart';
import '../widgets/app_confirmation_dialog.dart';
import '../widgets/profile/profile_collection_tabs.dart';
import '../widgets/profile/profile_favorites_grid.dart';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/profile_sequence_list.dart';
import '../widgets/sequence_builder/smart_connect_dialog.dart';
import 'saved_sequence_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.libraryController,
    required this.savedSequenceController,
    required this.onBuildSequence,
    required this.preferencesController,
    required this.sequenceBuilderNavKey,
  });

  final LibraryController libraryController;
  final SavedSequenceController savedSequenceController;
  final Future<void> Function(SavedSequence sequence) onBuildSequence;
  final ProfilePreferencesController preferencesController;
  final GlobalKey sequenceBuilderNavKey;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _arrivalHapticDelay = Duration(milliseconds: 90);

  String? _buildingSequenceId;

  ProfileCollection get _selectedCollection =>
      widget.preferencesController.selectedCollection ==
          ProfileCollectionPreference.sequences
      ? ProfileCollection.sequences
      : ProfileCollection.favorites;

  @override
  void initState() {
    super.initState();
    widget.libraryController.addListener(_onLibraryChanged);
    widget.savedSequenceController.addListener(_onSavedSequencesChanged);
    widget.preferencesController.addListener(_onPreferencesChanged);
  }

  @override
  void dispose() {
    widget.libraryController.removeListener(_onLibraryChanged);
    widget.savedSequenceController.removeListener(_onSavedSequencesChanged);
    widget.preferencesController.removeListener(_onPreferencesChanged);
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) setState(() {});
  }

  void _onSavedSequencesChanged() {
    if (mounted) setState(() {});
  }

  void _onPreferencesChanged() {
    if (mounted) setState(() {});
  }

  void _selectCollection(ProfileCollection collection) {
    if (_selectedCollection == collection) return;
    widget.preferencesController.selectCollection(
      collection == ProfileCollection.sequences
          ? ProfileCollectionPreference.sequences
          : ProfileCollectionPreference.favorites,
    );
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
      buttonText: library.getAddActionLabel(entry),
      showPrimaryAction: entry.isInstalled,
      viewIn3DLabel: library.getViewActionLabel(entry),
      onViewIn3D: () => library.performViewAction(entry),
      resolvePreviewPath: library.getOrDownloadPreview,
      resolveCachedPreviewPath: library.getCachedPreviewPath,
      isBookmarked: library.isBookmarked(entry.item),
      onBookmarkToggle: () => library.toggleBookmark(entry.item),
      onAnimatedPrimaryAction: (sourceKey) => _animateAndAdd(sourceKey, entry),
      onBeforePrimaryAction: () => confirmSmartConnection(
        context,
        plan: library.planConnection(entry),
        selectedAnimation: entry.item,
      ),
      onPrimaryAction: () => _handleFavoriteAdd(entry),
    );
  }

  Future<void> _handleFavoriteAdd(LibraryDisplayItem entry) async {
    try {
      await widget.libraryController.performPrimaryAction(entry);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not add ${entry.item.title}: $error'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.elevatedSurface,
          ),
        );
    }
  }

  Future<void> _animateAndAdd(
    GlobalKey sourceKey,
    LibraryDisplayItem entry, {
    Size? flightSize,
  }) async {
    unawaited(HapticFeedback.lightImpact());

    final library = widget.libraryController;
    final cachedPreviewPath = library.getCachedPreviewPath(
      entry.item.previewPath,
    );

    await AnimationCardFlight.run(
      sourceKey: sourceKey,
      targetKey: widget.sequenceBuilderNavKey,
      finalScale: AnimationCardFlightTuning.fullLibraryFinalScale,
      scaleEnd: AnimationCardFlightTuning.detailMorphScaleEnd,
      morphFrame: true,
      flightSize: flightSize,
      fadeOut: false,
      flightChild: AnimationPreviewFrame(
        previewPath: cachedPreviewPath ?? entry.item.previewPath,
        resolvePreviewPath: library.getOrDownloadPreview,
        resolveCachedPreviewPath: library.getCachedPreviewPath,
      ),
      actionTiming: AnimationFlightActionTiming.alongsideFlight,
      action: () => _handleFavoriteAdd(entry),
    );

    await Future<void>.delayed(_arrivalHapticDelay);
    await HapticFeedback.heavyImpact();
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

  void _openSavedSequenceDetails(SavedSequence sequence) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SavedSequenceDetailScreen(
          sequence: sequence,
          onBuildSequence: widget.onBuildSequence,
          savedSequenceController: widget.savedSequenceController,
          libraryController: widget.libraryController,
        ),
      ),
    );
  }

  Future<void> _buildSavedSequence(SavedSequence sequence) async {
    if (_buildingSequenceId != null) return;
    setState(() => _buildingSequenceId = sequence.id);

    try {
      await widget.onBuildSequence(sequence);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unity could not open this sequence.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.elevatedSurface,
          ),
        );
    } finally {
      if (mounted) setState(() => _buildingSequenceId = null);
    }
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
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [...previousChildren, ?currentChild],
                    );
                  },
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
                          entries: widget.savedSequenceController.sequences,
                          onSequencePressed: _openSavedSequenceDetails,
                          onBuildPressed: _buildSavedSequence,
                          buildingSequenceId: _buildingSequenceId,
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
