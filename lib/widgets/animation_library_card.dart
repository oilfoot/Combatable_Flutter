import 'package:flutter/material.dart';

import '../models/animation_library_item.dart';

class AnimationLibraryCard extends StatelessWidget {
  const AnimationLibraryCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onPrimaryAction,
    required this.buttonText,
    this.isDownloaded = true,
    this.isDownloading = false,
    this.showStatus = false,
    this.width = 240,
  });

  final AnimationLibraryItem item;
  final VoidCallback onTap;
  final Future<void> Function() onPrimaryAction;
  final String buttonText;
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
                ),
                const SizedBox(height: 4),
                Text(
                  'Start: ${item.startPosition}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'End: ${item.endPosition}',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (showStatus)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDownloaded
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isDownloading
                          ? 'Downloading...'
                          : isDownloaded
                          ? 'Installed'
                          : 'Not installed',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDownloaded
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isDownloading
                        ? null
                        : () async {
                            await onPrimaryAction();
                          },
                    child: Text(buttonText),
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
