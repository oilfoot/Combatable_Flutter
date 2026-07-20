import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class LibraryCategoryPill extends StatelessWidget {
  const LibraryCategoryPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: AnimatedContainer(
                duration: AppMotion.quick,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.glassControl,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.borderStrong,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: AppColors.textPrimary),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      label,
                      style: AppTypography.controlLabel.copyWith(
                        color: AppColors.textPrimary,
                      ),
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

class LibraryFilterButton extends StatelessWidget {
  const LibraryFilterButton({
    super.key,
    required this.activeCount,
    required this.onTap,
  });

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: activeCount > 0 ? AppColors.accent : AppColors.glassControl,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadii.medium),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.tune_rounded,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (activeCount > 0)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '$activeCount',
                          style: const TextStyle(
                            color: AppColors.background,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LibraryEmptyBrowseState extends StatelessWidget {
  const LibraryEmptyBrowseState({
    super.key,
    required this.hasFilters,
    required this.onClearFilters,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 34,
            color: AppColors.accentSoft,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No matching animations',
            style: AppTypography.componentTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasFilters
                ? 'Try changing or clearing your filters.'
                : 'This category does not contain any animations yet.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          if (hasFilters) ...[
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}
