import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/library_controller.dart';
import '../controllers/saved_sequence_controller.dart';
import '../models/animation_library_item.dart';
import '../models/saved_sequence.dart';
import '../theme/app_theme.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/app_confirmation_dialog.dart';
import '../widgets/sequence_builder_library.dart';
import 'sequence_builder_screen.dart';

class SavedSequenceDetailScreen extends StatefulWidget {
  const SavedSequenceDetailScreen({
    super.key,
    required this.sequence,
    required this.libraryController,
    required this.savedSequenceController,
    required this.onBuildSequence,
  });

  final SavedSequence sequence;
  final LibraryController libraryController;
  final SavedSequenceController savedSequenceController;
  final Future<void> Function(SavedSequence sequence) onBuildSequence;

  @override
  State<SavedSequenceDetailScreen> createState() =>
      _SavedSequenceDetailScreenState();
}

class _SavedSequenceDetailScreenState extends State<SavedSequenceDetailScreen> {
  static const int _historyLimit = 10;

  late SavedSequence _savedSequence;
  late final TextEditingController _nameController;
  late List<AnimationLibraryItem> _draftAnimations;
  final List<List<AnimationLibraryItem>> _undoHistory = [];
  final List<List<AnimationLibraryItem>> _redoHistory = [];
  final GlobalKey _libraryPanelKey = GlobalKey(
    debugLabel: 'saved-sequence-library-panel',
  );

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isBuilding = false;
  SequenceBuilderLibraryPanelState _libraryPanelState =
      SequenceBuilderLibraryPanelState.fullyCollapsed;

  @override
  void initState() {
    super.initState();
    _savedSequence = widget.sequence;
    _nameController = TextEditingController(text: _savedSequence.name);
    _draftAnimations = List.of(_savedSequence.animations);
    widget.libraryController.addListener(_onLibraryChanged);
  }

  @override
  void dispose() {
    widget.libraryController.removeListener(_onLibraryChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted && _isEditing) setState(() {});
  }

  bool get _hasDraftChanges {
    if (_nameController.text.trim() != _savedSequence.name) return true;
    if (_draftAnimations.length != _savedSequence.animations.length) {
      return true;
    }

    for (var index = 0; index < _draftAnimations.length; index++) {
      if (_draftAnimations[index].animationName !=
          _savedSequence.animations[index].animationName) {
        return true;
      }
    }
    return false;
  }

  bool get _canSave =>
      _hasDraftChanges &&
      _nameController.text.trim().isNotEmpty &&
      _draftAnimations.length >= 2 &&
      !_isSaving;

  List<LibraryDisplayItem> get _matchingLibraryItems {
    if (_draftAnimations.isEmpty) {
      return widget.libraryController.categoryFilteredItems;
    }

    final requiredPosition = _draftAnimations.last.endPosition;
    return widget.libraryController.categoryFilteredItems
        .where((entry) => entry.item.startPosition == requiredPosition)
        .toList(growable: false);
  }

  void _beginEditing() {
    setState(() {
      _draftAnimations = List.of(_savedSequence.animations);
      _nameController.text = _savedSequence.name;
      _undoHistory.clear();
      _redoHistory.clear();
      _libraryPanelState = SequenceBuilderLibraryPanelState.fullyCollapsed;
      _isEditing = true;
    });
  }

  void _discardEditing() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _draftAnimations = List.of(_savedSequence.animations);
      _nameController.text = _savedSequence.name;
      _undoHistory.clear();
      _redoHistory.clear();
      _libraryPanelState = SequenceBuilderLibraryPanelState.fullyCollapsed;
      _isEditing = false;
    });
  }

  Future<void> _requestCancelEditing() async {
    if (!_hasDraftChanges) {
      _discardEditing();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.black.withValues(alpha: AppOpacity.barrier),
      builder: (_) => const AppConfirmationDialog(
        title: 'Discard changes?',
        message: 'Your unsaved sequence changes will be lost.',
        confirmLabel: 'Discard',
        icon: Icons.edit_off_outlined,
        isDestructive: true,
      ),
    );

    if (confirmed == true && mounted) _discardEditing();
  }

  void _recordAnimationEdit(List<AnimationLibraryItem> previous) {
    _undoHistory.add(List.unmodifiable(previous));
    while (_undoHistory.length > _historyLimit) {
      _undoHistory.removeAt(0);
    }
    _redoHistory.clear();
  }

  void _removeFrom(int index) {
    if (index < 0 || index >= _draftAnimations.length) return;
    final previous = List<AnimationLibraryItem>.of(_draftAnimations);
    setState(() {
      _recordAnimationEdit(previous);
      _draftAnimations.removeRange(index, _draftAnimations.length);
    });
    HapticFeedback.mediumImpact();
  }

  void _clearDraft() {
    if (_draftAnimations.isEmpty) return;
    final previous = List<AnimationLibraryItem>.of(_draftAnimations);
    setState(() {
      _recordAnimationEdit(previous);
      _draftAnimations.clear();
    });
    HapticFeedback.mediumImpact();
  }

  void _undo() {
    if (_undoHistory.isEmpty) return;
    setState(() {
      _redoHistory.add(List.unmodifiable(_draftAnimations));
      _draftAnimations = List.of(_undoHistory.removeLast());
    });
    HapticFeedback.selectionClick();
  }

  void _redo() {
    if (_redoHistory.isEmpty) return;
    setState(() {
      _undoHistory.add(List.unmodifiable(_draftAnimations));
      _draftAnimations = List.of(_redoHistory.removeLast());
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _handleLibraryAction(LibraryDisplayItem entry) async {
    if (entry.isDownloading) return;
    if (widget.libraryController.requiresDownload(entry)) {
      await widget.libraryController.download(entry);
      return;
    }

    if (_draftAnimations.isNotEmpty &&
        entry.item.startPosition != _draftAnimations.last.endPosition) {
      return;
    }

    final previous = List<AnimationLibraryItem>.of(_draftAnimations);
    setState(() {
      _recordAnimationEdit(previous);
      _draftAnimations.add(entry.item);
    });
    await HapticFeedback.selectionClick();
  }

  Future<void> _showAnimationInfo(LibraryDisplayItem entry) {
    return AnimationInfoSheet.show(
      context,
      item: entry.item,
      isDownloaded: entry.isInstalled,
      isDownloading: entry.isDownloading,
      buttonText: widget.libraryController.getAddActionLabel(entry),
      showPrimaryAction: entry.isInstalled,
      viewIn3DLabel: widget.libraryController.getViewActionLabel(entry),
      onViewIn3D: () => widget.libraryController.performViewAction(entry),
      viewIn3DEnabled: !_isEditing,
      resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
      resolveCachedPreviewPath: widget.libraryController.getCachedPreviewPath,
      isBookmarked: widget.libraryController.isBookmarked(entry.item),
      onBookmarkToggle: () =>
          widget.libraryController.toggleBookmark(entry.item),
      onPrimaryAction: () => _handleLibraryAction(entry),
    );
  }

  Future<void> _showTimelineAnimationInfo(AnimationLibraryItem item) {
    LibraryDisplayItem? liveEntry;
    for (final entry in widget.libraryController.allItems) {
      if (entry.item.animationName == item.animationName) {
        liveEntry = entry;
        break;
      }
    }

    final entry =
        liveEntry ??
        LibraryDisplayItem(
          item: item,
          isRemote: item.addressKey != null,
          isInstalled: item.addressKey == null,
          isDownloading: false,
        );

    return AnimationInfoSheet.show(
      context,
      item: entry.item,
      isDownloaded: entry.isInstalled,
      isDownloading: entry.isDownloading,
      buttonText: '',
      showPrimaryAction: false,
      viewIn3DLabel: widget.libraryController.getViewActionLabel(entry),
      onViewIn3D: () => widget.libraryController.performViewAction(entry),
      viewIn3DEnabled: !_isEditing,
      onPrimaryAction: () async {},
      resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
      resolveCachedPreviewPath: widget.libraryController.getCachedPreviewPath,
      isBookmarked: widget.libraryController.isBookmarked(entry.item),
      onBookmarkToggle: () =>
          widget.libraryController.toggleBookmark(entry.item),
    );
  }

  Future<void> _saveDraft() async {
    if (!_canSave) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);

    try {
      final updated = await widget.savedSequenceController.update(
        id: _savedSequence.id,
        name: _nameController.text,
        animations: _draftAnimations,
      );
      if (!mounted) return;

      setState(() {
        _savedSequence = updated;
        _draftAnimations = List.of(updated.animations);
        _nameController.text = updated.name;
        _undoHistory.clear();
        _redoHistory.clear();
        _libraryPanelState = SequenceBuilderLibraryPanelState.fullyCollapsed;
        _isEditing = false;
      });
      await HapticFeedback.mediumImpact();
    } catch (_) {
      if (mounted) _showError('The sequence could not be saved.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _buildSequence() async {
    if (_isEditing || _isBuilding) return;
    setState(() => _isBuilding = true);

    try {
      await widget.onBuildSequence(_savedSequence);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _showError('Unity could not open this sequence.');
    } finally {
      if (mounted) setState(() => _isBuilding = false);
    }
  }

  Future<void> _deleteSequence() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.black.withValues(alpha: AppOpacity.barrier),
      builder: (_) => AppConfirmationDialog(
        title: 'Delete sequence?',
        message: 'Remove “${_savedSequence.name}” from My Sequences?',
        confirmLabel: 'Delete',
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
      ),
    );

    if (confirmed != true || !mounted) return;

    final deleted = await widget.savedSequenceController.delete(
      _savedSequence.id,
    );
    if (!mounted) return;

    if (!deleted) {
      _showError('The sequence could not be deleted.');
      return;
    }

    await HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.elevatedSurface,
        ),
      );
  }

  void _handleBack() {
    if (_isEditing) {
      _requestCancelEditing();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final displayedAnimations = _isEditing
        ? _draftAnimations
        : _savedSequence.animations;
    final bottomPadding = _isEditing
        ? SequenceBuilderLibrary.fullyCollapsedHeight + AppSpacing.panel
        : AppSpacing.panel;
    final isLibraryExpanded =
        _libraryPanelState == SequenceBuilderLibraryPanelState.expanded;

    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isEditing) _requestCancelEditing();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        bottomPadding,
                      ),
                      sliver: SliverList.list(
                        children: [
                          _DetailTopBar(
                            isEditing: _isEditing,
                            onBack: _handleBack,
                            onDelete: _isEditing ? null : _deleteSequence,
                          ),
                          const SizedBox(height: AppSpacing.panel),
                          _SequenceNameField(
                            controller: _nameController,
                            isEditing: _isEditing,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${displayedAnimations.length} animation steps  ·  '
                            '${displayedAnimations.isEmpty ? 'Any' : displayedAnimations.first.startPosition}'
                            ' → '
                            '${displayedAnimations.isEmpty ? 'Any' : displayedAnimations.last.endPosition}',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AnimatedSwitcher(
                            duration: AppMotion.standard,
                            switchInCurve: AppMotion.enter,
                            switchOutCurve: AppMotion.exit,
                            child: _isEditing
                                ? _EditControls(
                                    key: const ValueKey('edit-controls'),
                                    canSave: _canSave,
                                    isSaving: _isSaving,
                                    onCancel: _requestCancelEditing,
                                    onSave: _saveDraft,
                                  )
                                : _ViewControls(
                                    key: const ValueKey('view-controls'),
                                    isBuilding: _isBuilding,
                                    onBuild: _buildSequence,
                                    onEdit: _beginEditing,
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.panel),
                          Row(
                            children: [
                              Text(
                                'Timeline',
                                style: AppTypography.sectionTitle.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              AnimatedSwitcher(
                                duration: AppMotion.quick,
                                child: _isEditing
                                    ? SequenceTimelineActions(
                                        key: const ValueKey('timeline-actions'),
                                        canUndo: _undoHistory.isNotEmpty,
                                        canRedo: _redoHistory.isNotEmpty,
                                        canClear: _draftAnimations.isNotEmpty,
                                        onUndo: _undo,
                                        onRedo: _redo,
                                        onClear: _clearDraft,
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('no-timeline-actions'),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SequenceTimelineViewer(
                            animations: displayedAnimations,
                            resolvePreviewPath:
                                widget.libraryController.getOrDownloadPreview,
                            resolveCachedPreviewPath:
                                widget.libraryController.getCachedPreviewPath,
                            readOnly: !_isEditing,
                            onRemoveAt: _removeFrom,
                            onItemTap: _showTimelineAnimationInfo,
                            onAddStep: () => setState(
                              () => _libraryPanelState =
                                  SequenceBuilderLibraryPanelState.expanded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_isEditing || !isLibraryExpanded,
                  child: AnimatedOpacity(
                    opacity: _isEditing && isLibraryExpanded ? 1 : 0,
                    duration: AppMotion.standard,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(
                        () => _libraryPanelState =
                            SequenceBuilderLibraryPanelState.collapsed,
                      ),
                      child: ColoredBox(
                        color: AppColors.black.withValues(
                          alpha: AppOpacity.scrim,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedSlide(
                  offset: _isEditing ? Offset.zero : const Offset(0, 1.1),
                  duration: AppMotion.panel,
                  curve: AppMotion.enter,
                  child: IgnorePointer(
                    ignoring: !_isEditing,
                    child: SequenceBuilderLibrary(
                      panelState: _libraryPanelState,
                      panelSurfaceKey: _libraryPanelKey,
                      onStateChanged: (state) =>
                          setState(() => _libraryPanelState = state),
                      items: _matchingLibraryItems,
                      libraryController: widget.libraryController,
                      onItemTap: _showAnimationInfo,
                      onPrimaryAction: (_, entry) =>
                          _handleLibraryAction(entry),
                      showNavigationScrim: false,
                    ),
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

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({
    required this.isEditing,
    required this.onBack,
    required this.onDelete,
  });

  final bool isEditing;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          onPressed: onBack,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          icon: Icon(
            isEditing ? Icons.close_rounded : Icons.arrow_back_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          isEditing ? 'Edit sequence' : 'Saved sequence',
          style: AppTypography.componentTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (onDelete != null)
          IconButton.filled(
            tooltip: 'Delete sequence',
            onPressed: onDelete,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.destructive.withValues(
                alpha: AppOpacity.subtle,
              ),
              foregroundColor: AppColors.destructiveSoft,
              side: BorderSide(
                color: AppColors.destructive.withValues(
                  alpha: AppOpacity.muted,
                ),
              ),
            ),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
      ],
    );
  }
}

class _SequenceNameField extends StatelessWidget {
  const _SequenceNameField({
    required this.controller,
    required this.isEditing,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isEditing;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.standard,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(
          color: isEditing ? AppColors.borderStrong : AppColors.borderSubtle,
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: !isEditing,
        canRequestFocus: isEditing,
        showCursor: isEditing,
        enableInteractiveSelection: isEditing,
        onChanged: onChanged,
        style: AppTypography.sectionTitle.copyWith(
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          suffixIcon: isEditing
              ? const Icon(Icons.edit_outlined, color: AppColors.accentSoft)
              : null,
        ),
      ),
    );
  }
}

class _ViewControls extends StatelessWidget {
  const _ViewControls({
    super.key,
    required this.isBuilding,
    required this.onBuild,
    required this.onEdit,
  });

  final bool isBuilding;
  final VoidCallback onBuild;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: isBuilding ? null : onBuild,
            style: _primaryButtonStyle,
            icon: isBuilding
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Icon(Icons.play_circle_outline_rounded),
            label: Text(
              isBuilding ? 'Building…' : 'Build Sequence',
              style: AppTypography.controlLabel,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.buttonGap),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isBuilding ? null : onEdit,
            style: _secondaryButtonStyle,
            icon: const Icon(Icons.edit_outlined, size: 19),
            label: const Text('Edit', style: AppTypography.controlLabel),
          ),
        ),
      ],
    );
  }
}

class _EditControls extends StatelessWidget {
  const _EditControls({
    super.key,
    required this.canSave,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  final bool canSave;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isSaving ? null : onCancel,
            style: _secondaryButtonStyle,
            child: const Text('Cancel', style: AppTypography.controlLabel),
          ),
        ),
        const SizedBox(width: AppSpacing.buttonGap),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: canSave ? onSave : null,
            style: _primaryButtonStyle,
            icon: isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              isSaving ? 'Saving…' : 'Save changes',
              style: AppTypography.controlLabel,
            ),
          ),
        ),
      ],
    );
  }
}

final ButtonStyle _primaryButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  backgroundColor: AppColors.accent,
  foregroundColor: AppColors.textPrimary,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.button),
  ),
);

final ButtonStyle _secondaryButtonStyle = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  foregroundColor: AppColors.accentSoft,
  side: const BorderSide(color: AppColors.borderStrong),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.button),
  ),
);
