import 'package:flutter/material.dart';

import '../../models/animation_library_item.dart';
import 'animation_preview_frame.dart';

enum AnimationCardVariant { standard, compact }

class AnimationCard extends StatelessWidget {
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
    this.width = 240,
  }) : variant = AnimationCardVariant.standard,
       onInfoTap = null;

  const AnimationCard.compact({
    super.key,
    required this.item,
    required this.onPrimaryAction,
    required this.onInfoTap,
    required this.isDownloading,
    this.resolvePreviewPath,
    this.resolveCachedPreviewPath,
  }) : variant = AnimationCardVariant.compact,
       onTap = null,
       actionLabel = null,
       isDownloaded = true,
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
  final double? width;

  bool get _isCompact => variant == AnimationCardVariant.compact;
  double get _borderRadius => _isCompact ? 18 : 24;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: _isCompact
          ? Colors.white.withValues(alpha: 0.045)
          : Theme.of(context).cardColor,
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
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
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

    if (width == null) return card;
    return SizedBox(width: width, child: card);
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
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0x20000000), Color(0xB8000000)],
        stops: [0.40, 0.70, 1.0],
      );
    }

    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0x10000000), Color(0x7A000000)],
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
              color: Colors.black.withValues(alpha: 0.34),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
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
              Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
            ],
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: -0.25,
              shadows: [
                Shadow(
                  color: Color(0xAA000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
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
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: isLoading
              ? null
              : () async {
                  await onPressed();
                },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFC8A7FF).withValues(alpha: 0.52),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFC8A7FF),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 21, color: const Color(0xFFC8A7FF)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFC8A7FF),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
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
