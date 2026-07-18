import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/profile_layout.dart';

enum ProfileCollection { favorites, sequences }

class ProfileCollectionTabs extends StatelessWidget {
  const ProfileCollectionTabs({
    super.key,
    required this.selectedCollection,
    required this.onSelected,
  });

  final ProfileCollection selectedCollection;
  final ValueChanged<ProfileCollection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProfileTab(
            label: 'Favorites',
            icon: Icons.bookmark_border_rounded,
            isSelected: selectedCollection == ProfileCollection.favorites,
            onTap: () => onSelected(ProfileCollection.favorites),
          ),
        ),
        Expanded(
          child: _ProfileTab(
            label: 'My Sequences',
            icon: Icons.grid_view_rounded,
            isSelected: selectedCollection == ProfileCollection.sequences,
            onTap: () => onSelected(ProfileCollection.sequences),
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.small),
        child: SizedBox(
          height: ProfileLayout.tabHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: foreground),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.controlLabel.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  duration: AppMotion.quick,
                  curve: AppMotion.enter,
                  tween: Tween(end: isSelected ? 1 : 0),
                  child: const SizedBox(
                    width: double.infinity,
                    height: ProfileLayout.tabIndicatorHeight,
                    child: ColoredBox(color: AppColors.accent),
                  ),
                  builder: (context, scale, child) => Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(scale, 1, 1),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
