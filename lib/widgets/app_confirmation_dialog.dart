import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable confirmation dialog for actions that require explicit consent.
class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.icon,
    this.isDestructive = false,
    this.showCancelAction = true,
    this.cancelLabel = 'Cancel',
  });

  final String title;
  final String message;
  final String confirmLabel;
  final IconData icon;
  final bool isDestructive;
  final bool showCancelAction;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final actionColor = isDestructive
        ? AppColors.destructive
        : AppColors.accent;
    final actionContentColor = isDestructive
        ? AppColors.onDestructive
        : AppColors.textPrimary;
    final iconColor = isDestructive
        ? AppColors.destructiveSoft
        : AppColors.accentSoft;
    final iconSurface = isDestructive
        ? AppColors.destructive.withValues(alpha: AppOpacity.subtle)
        : AppColors.accent.withValues(alpha: AppOpacity.subtle);

    return Dialog(
      backgroundColor: AppColors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.panel),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(AppSpacing.dialog),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(AppRadii.dialog),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [AppShadows.dialog],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconSurface,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(title, style: AppTypography.dialogTitle)),
              ],
            ),
            const SizedBox(height: AppSpacing.dialogSection),
            Text(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                if (showCancelAction) ...[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                          side: const BorderSide(color: AppColors.borderStrong),
                        ),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.buttonGap),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: actionContentColor,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
