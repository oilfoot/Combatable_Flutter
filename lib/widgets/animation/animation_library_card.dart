import 'package:flutter/material.dart';

import '../../models/animation_library_item.dart';
import 'animation_preview_frame.dart';
import 'animation_primary_action_button.dart';
import 'animation_status_badge.dart';

class AnimationLibraryCard extends StatelessWidget {
  const AnimationLibraryCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onPrimaryAction,
    required this.buttonText,
    this.resolvePreviewPath,
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
  final bool isDownloaded;
  final bool isDownloading;
  final bool showStatus;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        margin: const EdgeInsets.only(right: 10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimationPreviewFrame(
                  previewPath: item.previewPath,
                  resolvePreviewPath: resolvePreviewPath,
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Clip: ${item.animationName}',
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Start: ${item.startPosition}',
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'End: ${item.endPosition}',
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (showStatus)
                  AnimationStatusBadge(
                    isDownloaded: isDownloaded,
                    isDownloading: isDownloading,
                  ),
                const Spacer(),
                AnimationPrimaryActionButton(
                  label: buttonText,
                  isLoading: isDownloading,
                  onPressed: onPrimaryAction,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
