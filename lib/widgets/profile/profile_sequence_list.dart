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
    final stepLabel = '${entry.stepCount} animation steps';
    final updatedLabel = _formatUpdatedLabel(entry.updatedAt);

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
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            stepLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${entry.startPosition}  →  ${entry.endPosition}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.accentSoft,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  updatedLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textDisabled,
                                  ),
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

String _formatUpdatedLabel(DateTime value) {
  final now = DateTime.now();
  final difference = now.difference(value);

  if (difference.inMinutes < 1) return 'Saved just now';
  if (difference.inHours < 1) {
    return 'Saved ${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return 'Saved ${difference.inHours}h ago';
  }
  if (difference.inDays == 1) return 'Saved yesterday';
  if (difference.inDays < 7) return 'Saved ${difference.inDays}d ago';

  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return 'Saved $day.$month.${value.year}';
}

class _SequenceCoverPlaceholder extends StatelessWidget {
  const _SequenceCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ProfileLayout.sequencePreviewSize,
      height: ProfileLayout.sequencePreviewSize,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(
          color: AppColors.accentSoft.withValues(alpha: AppOpacity.muted),
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.account_tree_outlined,
        size: 30,
        color: AppColors.accentSoft,
      ),
    );
  }
}
