import 'package:flutter/material.dart';

import '../../models/animation_library_item.dart';
import '../../theme/app_theme.dart';
import 'animation_preview_frame.dart';

enum AnimationCardVariant { standard, compact }

class AnimationCard extends StatelessWidget {
  static const double compactExtent = 112;

  const AnimationCard.standard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onPrimaryAction,
    required this.actionLabel,
    required this.isDownloaded,
    required this.isDownloading,
    this.resolvePreviewPath,
    this.resolveCachedPreviewPath,
    this.flightKey,
    this.width = 240,
  }) : variant = AnimationCardVariant.standard,
       onInfoTap = null;

  const AnimationCard.compact({
    super.key,
    required this.item,
    required this.onPrimaryAction,
    required this.onInfoTap,
    required this.isDownloaded,
    required this.isDownloading,
    this.resolvePreviewPath,
    this.resolveCachedPreviewPath,
    this.flightKey,
  }) : variant = AnimationCardVariant.compact,
       onTap = null,
       actionLabel = null,
       width = null;

  final AnimationLibraryItem item;
  final AnimationCardVariant variant;
  final VoidCallback? onTap;
  final VoidCallback? onInfoTap;
  final Future<void> Function() onPrimaryAction;
  final String? actionLabel;
  final bool isDownloaded;
  final bool isDownloading;
  final Future<String?> Function(String? previewPath)? resolvePreviewPath;
  final String? Function(String? previewPath)? resolveCachedPreviewPath;
  final GlobalKey? flightKey;
  final double? width;

  bool get _isCompact => variant == AnimationCardVariant.compact;
  double get _borderRadius => _isCompact ? AppRadii.card : AppRadii.dialog;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: _isCompact ? AppColors.surface : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(_borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(_borderRadius),
        onTap: _resolveCardTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimationPreviewFrame(
              previewPath: item.previewPath,
              resolvePreviewPath: resolvePreviewPath,
              resolveCachedPreviewPath: resolveCachedPreviewPath,
            ),
            DecoratedBox(decoration: BoxDecoration(gradient: _gradient)),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_borderRadius),
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                ),
              ),
            ),
            if (_isCompact) ..._buildCompactOverlay(),
            if (!_isCompact) _buildStandardOverlay(),
          ],
        ),
      ),
    );

    final sizedCard = width == null
        ? card
        : SizedBox(width: width, child: card);

    return RepaintBoundary(key: flightKey, child: sizedCard);
  }

  VoidCallback? _resolveCardTap() {
    if (!_isCompact) return onTap;
    if (isDownloading) return null;

    return () async {
      await onPrimaryAction();
    };
  }

  LinearGradient get _gradient {
    if (_isCompact) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.transparent,
          AppColors.black.withValues(alpha: AppOpacity.subtle),
          AppColors.black.withValues(alpha: AppOpacity.barrier),
        ],
        stops: [0.40, 0.70, 1.0],
      );
    }

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.transparent,
        AppColors.black.withValues(alpha: AppOpacity.faint),
        AppColors.black.withValues(alpha: AppOpacity.strong),
      ],
      stops: [0.46, 0.76, 1.0],
    );
  }

  List<Widget> _buildCompactOverlay() {
    return [
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
              color: AppColors.black.withValues(alpha: AppOpacity.medium),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: const Icon(
              Icons.info_outline,
              size: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
      if (!isDownloaded || isDownloading)
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.black.withValues(alpha: AppOpacity.strong),
              border: Border.all(
                color: AppColors.accentSoft.withValues(
                  alpha: AppOpacity.medium,
                ),
              ),
            ),
            child: isDownloading
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppColors.accentSoft,
                    ),
                  )
                : const Icon(
                    Icons.download_rounded,
                    size: 15,
                    color: AppColors.accentSoft,
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
          style: AppTypography.compactCardTitle.copyWith(
            color: AppColors.textPrimary,
            shadows: const [AppShadows.compactImageText],
          ),
        ),
      ),
    ];
  }

  Widget _buildStandardOverlay() {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.button.copyWith(
              color: AppColors.textPrimary,
              height: 1.05,
              letterSpacing: -0.25,
              shadows: [AppShadows.imageText],
            ),
          ),
          const SizedBox(height: 10),
          _AnimationCardActionButton(
            label: actionLabel ?? 'Add',
            icon: isDownloaded ? Icons.add : Icons.download_rounded,
            isLoading: isDownloading,
            onPressed: onPrimaryAction,
          ),
        ],
      ),
    );
  }
}

class _AnimationCardActionButton extends StatelessWidget {
  const _AnimationCardActionButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: isLoading
              ? null
              : () async {
                  await onPressed();
                },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: AppColors.accentSoft.withValues(
                  alpha: AppOpacity.strong,
                ),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentSoft,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 21, color: AppColors.accentSoft),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.controlLabel.copyWith(
                            color: AppColors.accentSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
