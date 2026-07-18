import 'package:flutter/material.dart';

import '../models/saved_sequence.dart';
import '../theme/app_theme.dart';
import 'sequence_builder_screen.dart';

class SavedSequenceDetailScreen extends StatefulWidget {
  const SavedSequenceDetailScreen({
    super.key,
    required this.sequence,
    required this.resolvePreviewPath,
    required this.resolveCachedPreviewPath,
    required this.onBuildSequence,
    required this.onEditSequence,
  });

  final SavedSequence sequence;
  final Future<String?> Function(String? previewPath) resolvePreviewPath;
  final String? Function(String? previewPath) resolveCachedPreviewPath;
  final Future<void> Function(SavedSequence sequence) onBuildSequence;
  final ValueChanged<SavedSequence> onEditSequence;

  @override
  State<SavedSequenceDetailScreen> createState() =>
      _SavedSequenceDetailScreenState();
}

class _SavedSequenceDetailScreenState extends State<SavedSequenceDetailScreen> {
  bool _isBuilding = false;

  Future<void> _buildSequence() async {
    if (_isBuilding) return;
    setState(() => _isBuilding = true);

    try {
      await widget.onBuildSequence(widget.sequence);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isBuilding = false);
    }
  }

  void _editSequence() {
    widget.onEditSequence(widget.sequence);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sequence = widget.sequence;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.panel,
              ),
              sliver: SliverList.list(
                children: [
                  _DetailTopBar(onBack: () => Navigator.of(context).pop()),
                  const SizedBox(height: AppSpacing.panel),
                  Text(
                    sequence.name,
                    style: AppTypography.screenTitle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${sequence.stepCount} animation steps  ·  '
                    '${sequence.startPosition} → ${sequence.endPosition}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _isBuilding ? null : _buildSequence,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.button,
                              ),
                            ),
                          ),
                          icon: _isBuilding
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textPrimary,
                                  ),
                                )
                              : const Icon(Icons.play_circle_outline_rounded),
                          label: Text(
                            _isBuilding ? 'Building…' : 'Build Sequence',
                            style: AppTypography.controlLabel,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.buttonGap),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isBuilding ? null : _editSequence,
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
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          label: const Text(
                            'Edit',
                            style: AppTypography.controlLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.panel),
                  Text(
                    'Timeline',
                    style: AppTypography.sectionTitle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SequenceTimelineViewer(
                    animations: sequence.animations,
                    resolvePreviewPath: widget.resolvePreviewPath,
                    resolveCachedPreviewPath: widget.resolveCachedPreviewPath,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.onBack});

  final VoidCallback onBack;

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
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'Saved sequence',
          style: AppTypography.componentTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
