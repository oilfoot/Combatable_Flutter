import 'package:flutter/material.dart';

import '../../models/animation_library_item.dart';
import 'animation_preview_frame.dart';

class AnimationLibraryCard extends StatelessWidget {
  const AnimationLibraryCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onPrimaryAction,
    required this.buttonText,
    this.resolvePreviewPath,
    this.resolveCachedPreviewPath,
    this.isDownloaded = true,
    this.isDownloading = false,
    this.showStatus = false,
    this.width = 240,
  });

  final AnimationLibraryItem item;
  final VoidCallback onTap;
  final Future<void> Function() onPrimaryAction;
  final String buttonText;
  final Future<String?> Function(String? previewPath)? resolvePreviewPath;
  final String? Function(String? previewPath)? resolveCachedPreviewPath;
  final bool isDownloaded;
  final bool isDownloading;
  final bool showStatus;
  final double width;

  @override
  Widget build(BuildContext context) {
    final actionLabel = isDownloading
        ? 'Downloading...'
        : isDownloaded
        ? 'Add'
        : 'Download';

    final actionIcon = isDownloaded ? Icons.add : Icons.download_rounded;

    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: AnimationPreviewFrame(
                  previewPath: item.previewPath,
                  resolvePreviewPath: resolvePreviewPath,
                  resolveCachedPreviewPath: resolveCachedPreviewPath,
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x10000000),
                        Color(0x7A000000),
                      ],
                      stops: [0.46, 0.76, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.10),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
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
                    _CardActionButton(
                      label: actionLabel,
                      icon: actionIcon,
                      isLoading: isDownloading,
                      onPressed: onPrimaryAction,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
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
        color: Colors.white.withOpacity(0.08),
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
                color: const Color(0xFFC8A7FF).withOpacity(0.52),
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
                      Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFFC8A7FF),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
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
