import 'package:flutter/material.dart';

import '../../models/saved_sequence.dart';
import '../../theme/app_theme.dart';
import '../../theme/profile_layout.dart';

class ProfileSequenceList extends StatelessWidget {
  const ProfileSequenceList({
    super.key,
    required this.entries,
    required this.onSequencePressed,
  });

  final List<SavedSequence> entries;
  final ValueChanged<SavedSequence> onSequencePressed;

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
        );
      },
    );
  }
}

class _SavedSequenceRow extends StatelessWidget {
  const _SavedSequenceRow({required this.entry, required this.onTap});

  final SavedSequence entry;
  final VoidCallback onTap;

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
                          Row(
                            children: [
                              _StepCountBadge(count: entry.stepCount),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _PositionRange(
                                  startPosition: entry.startPosition,
                                  endPosition: entry.endPosition,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
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

class _StepCountBadge extends StatelessWidget {
  const _StepCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: AppColors.accentSoft.withValues(alpha: AppOpacity.muted),
        ),
      ),
      child: Text(
        '$count steps',
        style: AppTypography.caption.copyWith(
          color: AppColors.accentSoft,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PositionRange extends StatelessWidget {
  const _PositionRange({
    required this.startPosition,
    required this.endPosition,
  });

  final String startPosition;
  final String endPosition;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PositionLine(label: 'Start', value: startPosition),
        const SizedBox(height: AppSpacing.xs),
        _PositionLine(label: 'End', value: endPosition),
      ],
    );
  }
}

class _PositionLine extends StatelessWidget {
  const _PositionLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      TextSpan(
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        children: [
          TextSpan(text: '$label  '),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AppColors.accentSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
