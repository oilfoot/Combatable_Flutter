import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/app_theme.dart';
import '../app_shimmer.dart';

class AnimationPreviewFrame extends StatefulWidget {
  const AnimationPreviewFrame({
    super.key,
    required this.previewPath,
    required this.resolvePreviewPath,
    this.resolveCachedPreviewPath,
    this.aspectRatio = 16 / 9,
  });

  final String? previewPath;
  final Future<String?> Function(String? previewPath)? resolvePreviewPath;
  final String? Function(String? previewPath)? resolveCachedPreviewPath;
  final double aspectRatio;

  @override
  State<AnimationPreviewFrame> createState() => _AnimationPreviewFrameState();
}

class _AnimationPreviewFrameState extends State<AnimationPreviewFrame> {
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
  void didUpdateWidget(covariant AnimationPreviewFrame oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.previewPath != widget.previewPath ||
        oldWidget.resolvePreviewPath != widget.resolvePreviewPath ||
        oldWidget.resolveCachedPreviewPath != widget.resolveCachedPreviewPath) {
      _resolvedPreviewPath = widget.previewPath;
      _loadPreviewIfNeeded();
    }
  }

  void _loadPreviewIfNeeded() {
    _previewLoadTimer?.cancel();

    final resolver = widget.resolvePreviewPath;
    final previewPath = widget.previewPath;

    if (resolver == null || previewPath == null || previewPath.trim().isEmpty) {
      _isLoading = false;
      return;
    }

    final cachedPreviewPath = widget.resolveCachedPreviewPath?.call(
      previewPath,
    );

    if (cachedPreviewPath != null && cachedPreviewPath.trim().isNotEmpty) {
      setState(() {
        _resolvedPreviewPath = cachedPreviewPath;
        _isLoading = false;
      });
      return;
    }

    _resolvedPreviewPath = null;
    _isLoading = true;
    _schedulePreviewLoad(const Duration(milliseconds: 100));
  }

  void _schedulePreviewLoad(Duration delay) {
    _previewLoadTimer?.cancel();
    _previewLoadTimer = Timer(delay, () async {
      if (!mounted) return;

      if (!_isVisibleInScrollable() ||
          Scrollable.recommendDeferredLoadingForContext(context)) {
        _schedulePreviewLoad(const Duration(milliseconds: 140));
        return;
      }

      final resolver = widget.resolvePreviewPath;
      final previewPath = widget.previewPath;
      if (resolver == null || previewPath == null) return;

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

  bool _isVisibleInScrollable() {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return true;

    final renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached) return false;

    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return true;

    final position = scrollable.position;
    final leading = viewport.getOffsetToReveal(renderObject, 0).offset;
    final trailing = viewport.getOffsetToReveal(renderObject, 1).offset;
    final visibleStart = position.pixels;
    final visibleEnd = visibleStart + position.viewportDimension;
    return trailing >= visibleStart && leading <= visibleEnd;
  }

  @override
  void dispose() {
    _previewLoadTimer?.cancel();
    super.dispose();
  }

  bool get _hasPreviewPath =>
      _resolvedPreviewPath != null && _resolvedPreviewPath!.trim().isNotEmpty;

  bool get _isLocalFile =>
      _hasPreviewPath && _resolvedPreviewPath!.startsWith('/');

  bool get _isRemoteUrl =>
      _hasPreviewPath &&
      (_resolvedPreviewPath!.startsWith('http://') ||
          _resolvedPreviewPath!.startsWith('https://'));

  bool get _isImageLikePreview {
    if (!_hasPreviewPath) return false;

    final lower = _resolvedPreviewPath!.toLowerCase();

    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  bool get _isVideoPreview =>
      _hasPreviewPath && _resolvedPreviewPath!.toLowerCase().endsWith('.mp4');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
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
    if (!_hasPreviewPath) return _buildPlaceholder(context);
    if (_isVideoPreview) return _buildVideoPlaceholder(context);
    if (!_isImageLikePreview) return _buildPlaceholder(context);

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
    return const AppShimmer(child: ColoredBox(color: AppColors.textPrimary));
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
}
