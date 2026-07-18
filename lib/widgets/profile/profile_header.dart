import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/profile_layout.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.onSettingsPressed});

  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: ProfileLayout.settingsButtonSize,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Profile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.screenTitle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                tooltip: 'Account and settings',
                onPressed: onSettingsPressed,
                icon: const Icon(Icons.settings_outlined, size: 21),
                color: AppColors.accentSoft,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: ProfileLayout.settingsButtonSize,
                  height: ProfileLayout.settingsButtonSize,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.panel),
        const _ProfileIdentity(),
      ],
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: ProfileLayout.avatarSize,
          height: ProfileLayout.avatarSize,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'FB',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 27,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fritz Bohnert',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sectionTitle,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'fritz@combatable.com',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              SizedBox(height: AppSpacing.sm),
              _ProBadge(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(
          color: AppColors.accentSoft.withValues(alpha: AppOpacity.medium),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          'Combatable Pro',
          style: TextStyle(
            color: AppColors.accentSoft,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
