import 'package:flutter/material.dart';

import '../../models/saved_sequence.dart';
import '../../theme/app_theme.dart';
import '../../theme/profile_layout.dart';

class ProfileSequenceList extends StatelessWidget {
  const ProfileSequenceList({
    super.key,
    required this.entries,
    required this.onSequencePressed,
    required this.onBuildPressed,
    required this.buildingSequenceId,
  });

  final List<SavedSequence> entries;
  final ValueChanged<SavedSequence> onSequencePressed;
  final ValueChanged<SavedSequence> onBuildPressed;
  final String? buildingSequenceId;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _SavedSequenceRow(
          entry: entry,
          onTap: () => onSequencePressed(entry),
          onBuild: () => onBuildPressed(entry),
          isBuilding: buildingSequenceId == entry.id,
        );
      },
    );
  }
}

class _SavedSequenceRow extends StatelessWidget {
  const _SavedSequenceRow({
    required this.entry,
    required this.onTap,
    required this.onBuild,
    required this.isBuilding,
  });

  final SavedSequence entry;
  final VoidCallback onTap;
  final VoidCallback onBuild;
  final bool isBuilding;

  @override
  Widget build(BuildContext context) {
    final stepLabel = '${entry.stepCount} steps';

    return Semantics(
      button: true,
      label:
          '${entry.name}, $stepLabel, '
          '${entry.startPosition} to ${entry.endPosition}',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: ProfileLayout.sequenceRowHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderSubtle),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const _SequenceCoverPlaceholder(),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.componentTitle.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _PositionLine(
                            label: 'Start',
                            value: entry.startPosition,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          _PositionLine(label: 'End', value: entry.endPosition),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${entry.stepCount} animation '
                            'step${entry.stepCount == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      tooltip: 'Build sequence',
                      onPressed: isBuilding ? null : onBuild,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accent.withValues(
                          alpha: AppOpacity.subtle,
                        ),
                        foregroundColor: AppColors.accentSoft,
                        side: BorderSide(
                          color: AppColors.accentSoft.withValues(
                            alpha: AppOpacity.muted,
                          ),
                        ),
                      ),
                      icon: isBuilding
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentSoft,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SequenceCoverPlaceholder extends StatelessWidget {
  const _SequenceCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ProfileLayout.sequencePreviewSize,
      height: ProfileLayout.sequencePreviewSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(
          color: AppColors.accentSoft.withValues(alpha: AppOpacity.muted),
        ),
      ),
      child: const Icon(
        Icons.account_tree_outlined,
        size: 30,
        color: AppColors.accentSoft,
      ),
    );
  }
}

class _PositionLine extends StatelessWidget {
  const _PositionLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.accentSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
