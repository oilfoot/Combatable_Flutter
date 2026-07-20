import 'package:flutter/material.dart';

import '../../controllers/library_controller.dart';
import '../../theme/app_theme.dart';
import '../animation/animation_card.dart';

class LibraryExploreSection extends StatelessWidget {
  const LibraryExploreSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    this.placeholderCount = 0,
    required this.onViewAll,
    required this.cardBuilder,
  });

  static const double cardWidth = 174;
  static const double cardHeight = 244;

  final String title;
  final String subtitle;
  final List<LibraryDisplayItem> items;
  final int placeholderCount;
  final VoidCallback onViewAll;
  final Widget Function(LibraryDisplayItem item, double width) cardBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.sectionTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  'View all',
                  style: AppTypography.label.copyWith(
                    color: AppColors.accentSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: items.length + placeholderCount,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return const SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: AnimationCardSkeleton.standard(
                    borderRadius: AppRadii.card,
                  ),
                );
              }
              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: cardBuilder(items[index], cardWidth),
              );
            },
          ),
        ),
      ],
    );
  }
}

class LibraryExploreSectionSkeleton extends StatelessWidget {
  const LibraryExploreSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 170,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SizedBox(
          height: LibraryExploreSection.cardHeight,
          child: Row(
            children: [
              Expanded(child: AnimationCardSkeleton.standard()),
              SizedBox(width: AppSpacing.md),
              Expanded(child: AnimationCardSkeleton.standard()),
            ],
          ),
        ),
      ],
    );
  }
}
