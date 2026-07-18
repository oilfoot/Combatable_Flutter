import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/profile_layout.dart';

class ProfileSequenceEntry {
  const ProfileSequenceEntry({
    required this.title,
    required this.stepCount,
    required this.startPosition,
    required this.endPosition,
    required this.updatedLabel,
  });

  final String title;
  final int stepCount;
  final String startPosition;
  final String endPosition;
  final String updatedLabel;
}

class ProfileSequenceList extends StatelessWidget {
  const ProfileSequenceList({
    super.key,
    required this.entries,
    required this.onSequencePressed,
  });

  final List<ProfileSequenceEntry> entries;
  final ValueChanged<ProfileSequenceEntry> onSequencePressed;

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

  final ProfileSequenceEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stepLabel = '${entry.stepCount} animation steps';

    return Semantics(
      button: true,
      label:
          '${entry.title}, $stepLabel, '
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
                            entry.title,
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
                                  entry.updatedLabel,
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
