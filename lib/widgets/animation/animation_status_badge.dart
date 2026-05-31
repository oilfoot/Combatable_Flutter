import 'package:flutter/material.dart';

class AnimationStatusBadge extends StatelessWidget {
  const AnimationStatusBadge({
    super.key,
    required this.isDownloaded,
    required this.isDownloading,
  });

  final bool isDownloaded;
  final bool isDownloading;

  @override
  Widget build(BuildContext context) {
    final label = isDownloading
        ? 'Downloading...'
        : isDownloaded
        ? 'Installed'
        : 'Not installed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDownloaded ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDownloaded ? Colors.green.shade900 : Colors.orange.shade900,
        ),
      ),
    );
  }
}
