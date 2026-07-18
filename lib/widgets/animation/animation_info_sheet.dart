import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/animation_library_item.dart';
import '../../theme/app_theme.dart';
import 'animation_preview_frame.dart';

class AnimationInfoSheet extends StatelessWidget {
  const AnimationInfoSheet({
    super.key,
    required this.item,
    required this.isDownloaded,
    required this.isDownloading,
    required this.buttonText,
    required this.onPrimaryAction,
    this.showPrimaryAction = true,
    this.onAnimatedPrimaryAction,
    this.onBeforePrimaryAction,
    this.resolvePreviewPath,
    this.resolveCachedPreviewPath,
    this.isBookmarked = false,
    this.onBookmarkToggle,
    this.viewIn3DLabel = 'View in 3D',
    this.onViewIn3D,
    this.viewIn3DEnabled = true,
  });

  final AnimationLibraryItem item;
  final bool isDownloaded;
  final bool isDownloading;
  final String buttonText;
  final Future<void> Function() onPrimaryAction;
  final bool showPrimaryAction;
  final Future<void> Function(GlobalKey sourceKey)? onAnimatedPrimaryAction;
  final Future<bool> Function()? onBeforePrimaryAction;
  final Future<String?> Function(String? previewPath)? resolvePreviewPath;
  final String? Function(String? previewPath)? resolveCachedPreviewPath;
  final bool isBookmarked;
  final Future<void> Function()? onBookmarkToggle;
  final String viewIn3DLabel;
  final Future<void> Function()? onViewIn3D;
  final bool viewIn3DEnabled;

  static Future<void> show(
    BuildContext context, {
    required AnimationLibraryItem item,
    required bool isDownloaded,
    required bool isDownloading,
    required String buttonText,
    required Future<void> Function() onPrimaryAction,
    bool showPrimaryAction = true,
    Future<void> Function(GlobalKey sourceKey)? onAnimatedPrimaryAction,
    Future<bool> Function()? onBeforePrimaryAction,
    Future<String?> Function(String? previewPath)? resolvePreviewPath,
    String? Function(String? previewPath)? resolveCachedPreviewPath,
    bool isBookmarked = false,
    Future<void> Function()? onBookmarkToggle,
    String viewIn3DLabel = 'View in 3D',
    Future<void> Function()? onViewIn3D,
    bool viewIn3DEnabled = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.black.withValues(alpha: AppOpacity.barrier),
      builder: (_) {
        return AnimationInfoSheet(
          item: item,
          isDownloaded: isDownloaded,
          isDownloading: isDownloading,
          buttonText: buttonText,
          onPrimaryAction: onPrimaryAction,
          showPrimaryAction: showPrimaryAction,
          onAnimatedPrimaryAction: onAnimatedPrimaryAction,
          onBeforePrimaryAction: onBeforePrimaryAction,
          resolvePreviewPath: resolvePreviewPath,
          resolveCachedPreviewPath: resolveCachedPreviewPath,
          isBookmarked: isBookmarked,
          onBookmarkToggle: onBookmarkToggle,
          viewIn3DLabel: viewIn3DLabel,
          onViewIn3D: onViewIn3D,
          viewIn3DEnabled: viewIn3DEnabled,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryActionKey = GlobalKey(
      debugLabel: 'animation-info-primary-action',
    );
    final previewFlightKey = GlobalKey(
      debugLabel: 'animation-info-preview-flight-source',
    );
    final description = item.description?.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.72,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.panel),
            ),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [AppShadows.panel],
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Animation',
                        style: AppTypography.sectionTitle,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RepaintBoundary(
                        key: previewFlightKey,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: AnimationPreviewFrame(
                              previewPath: item.previewPath,
                              aspectRatio: 1,
                              resolvePreviewPath: resolvePreviewPath,
                              resolveCachedPreviewPath:
                                  resolveCachedPreviewPath,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTypography.screenTitle.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (onBookmarkToggle != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            _AnimationInfoBookmarkButton(
                              initiallyBookmarked: isBookmarked,
                              onToggle: onBookmarkToggle!,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _InfoChip(label: 'Start', value: item.startPosition),
                          _InfoChip(label: 'End', value: item.endPosition),
                          _InfoChip(
                            label: 'Status',
                            value: isDownloading
                                ? 'Downloading...'
                                : isDownloaded
                                ? 'Installed'
                                : 'Not installed',
                          ),
                        ],
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const Text(
                          'About this animation',
                          style: AppTypography.componentTitle,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          description,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (item.tags.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final tag in item.tags) _TagChip(label: tag),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    if (onViewIn3D != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isDownloading || !viewIn3DEnabled
                              ? null
                              : () async {
                                  await HapticFeedback.selectionClick();
                                  await onViewIn3D!();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.textPrimary,
                            disabledBackgroundColor: AppColors.surface,
                            disabledForegroundColor: AppColors.textDisabled,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.button,
                              ),
                            ),
                            textStyle: AppTypography.button,
                          ),
                          icon: const Icon(Icons.view_in_ar_rounded),
                          label: Text(viewIn3DLabel),
                        ),
                      ),
                    if (onViewIn3D != null && showPrimaryAction)
                      const SizedBox(height: AppSpacing.buttonGap),
                    if (showPrimaryAction)
                      RepaintBoundary(
                        key: primaryActionKey,
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isDownloading
                                ? null
                                : () async {
                                    final canProceed =
                                        await onBeforePrimaryAction?.call() ??
                                        true;
                                    if (!canProceed || !context.mounted) return;

                                    final animatedAction =
                                        onAnimatedPrimaryAction;
                                    if (animatedAction == null) {
                                      await onPrimaryAction();
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                      return;
                                    }

                                    final flight = animatedAction(
                                      previewFlightKey,
                                    );
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                    unawaited(flight);
                                  },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              foregroundColor: AppColors.accentSoft,
                              side: const BorderSide(
                                color: AppColors.borderStrong,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.button,
                                ),
                              ),
                              textStyle: AppTypography.controlLabel,
                            ),
                            icon: const Icon(Icons.playlist_add_rounded),
                            label: Text(buttonText),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimationInfoBookmarkButton extends StatefulWidget {
  const _AnimationInfoBookmarkButton({
    required this.initiallyBookmarked,
    required this.onToggle,
  });

  final bool initiallyBookmarked;
  final Future<void> Function() onToggle;

  @override
  State<_AnimationInfoBookmarkButton> createState() =>
      _AnimationInfoBookmarkButtonState();
}

class _AnimationInfoBookmarkButtonState
    extends State<_AnimationInfoBookmarkButton> {
  late bool _isBookmarked = widget.initiallyBookmarked;
  bool _isUpdating = false;

  Future<void> _toggle() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    await HapticFeedback.selectionClick();
    await widget.onToggle();

    if (!mounted) return;
    setState(() {
      _isBookmarked = !_isBookmarked;
      _isUpdating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _isBookmarked ? 'Remove bookmark' : 'Bookmark animation',
      onPressed: _isUpdating ? null : _toggle,
      icon: Icon(
        _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      ),
      color: _isBookmarked ? AppColors.accentSoft : AppColors.textPrimary,
      disabledColor: AppColors.textDisabled,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.label.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: AppColors.accentSoft.withValues(alpha: AppOpacity.muted),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.accentSoft),
      ),
    );
  }
}
