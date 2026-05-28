import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/animation_library_item.dart';

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
                _PreviewFrame(
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

class _PreviewFrame extends StatefulWidget {
  const _PreviewFrame({
    required this.previewPath,
    required this.resolvePreviewPath,
  });

  final String? previewPath;
  final Future<String?> Function(String? previewPath)? resolvePreviewPath;

  @override
  State<_PreviewFrame> createState() => _PreviewFrameState();
}

class _PreviewFrameState extends State<_PreviewFrame> {
  String? _resolvedPreviewPath;
  bool _isLoading = false;
  Timer? _previewLoadTimer;

  @override
  void initState() {
    super.initState();
    _resolvedPreviewPath = widget.previewPath;
    _loadPreviewIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _PreviewFrame oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.previewPath != widget.previewPath ||
        oldWidget.resolvePreviewPath != widget.resolvePreviewPath) {
      _resolvedPreviewPath = widget.previewPath;
      _loadPreviewIfNeeded();
    }
  }

  void _loadPreviewIfNeeded() {
    _previewLoadTimer?.cancel();

    final resolver = widget.resolvePreviewPath;
    final previewPath = widget.previewPath;

    if (resolver == null || previewPath == null || previewPath.trim().isEmpty) {
      return;
    }

    _previewLoadTimer = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;

      setState(() {
        _resolvedPreviewPath = null;
        _isLoading = true;
      });

      try {
        final resolved = await resolver(previewPath);

        if (!mounted) return;

        setState(() {
          _resolvedPreviewPath = resolved ?? previewPath;
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted) return;

        setState(() {
          _resolvedPreviewPath = previewPath;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _previewLoadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading && !_hasPreviewPath) {
      return _buildLoadingPlaceholder(context);
    }

    if (!_hasPreviewPath) {
      return _buildPlaceholder(context);
    }

    if (_isVideoPreview) {
      return _buildVideoPlaceholder(context);
    }

    if (!_isImageLikePreview) {
      return _buildPlaceholder(context);
    }

    if (_isLocalFile) {
      final file = File(_resolvedPreviewPath!);

      if (!file.existsSync()) {
        return _buildPlaceholder(context);
      }

      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(context),
      );
    }

    if (_isRemoteUrl) {
      return Image.network(
        _resolvedPreviewPath!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder(context);
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(context),
      );
    }

    return _buildPlaceholder(context);
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Icon(
        Icons.movie_outlined,
        size: 34,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Icon(
        Icons.play_circle_outline,
        size: 34,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  bool get _hasPreviewPath =>
      _resolvedPreviewPath != null && _resolvedPreviewPath!.trim().isNotEmpty;

  bool get _isLocalFile {
    if (!_hasPreviewPath) return false;
    return _resolvedPreviewPath!.startsWith('/');
  }

  bool get _isRemoteUrl {
    if (!_hasPreviewPath) return false;
    return _resolvedPreviewPath!.startsWith('http://') ||
        _resolvedPreviewPath!.startsWith('https://');
  }

  bool get _isImageLikePreview {
    if (!_hasPreviewPath) return false;

    final lower = _resolvedPreviewPath!.toLowerCase();

    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  bool get _isVideoPreview {
    if (!_hasPreviewPath) return false;
    return _resolvedPreviewPath!.toLowerCase().endsWith('.mp4');
  }
}
