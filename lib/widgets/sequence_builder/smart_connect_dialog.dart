import 'package:flutter/material.dart';

import '../../models/animation_library_item.dart';
import '../../services/sequence_connection_planner.dart';
import '../../theme/app_theme.dart';
import '../app_confirmation_dialog.dart';

Future<bool> confirmSmartConnection(
  BuildContext context, {
  required SequenceConnectionPlan plan,
  required AnimationLibraryItem selectedAnimation,
}) async {
  if (plan.status == SequenceConnectionStatus.direct) return true;

  if (plan.status == SequenceConnectionStatus.unavailable) {
    await showDialog<bool>(
      context: context,
      barrierColor: AppColors.black.withValues(alpha: AppOpacity.barrier),
      builder: (_) => const AppConfirmationDialog(
        title: 'This move doesn’t fit yet',
        message:
            'Your last move ends in a different position than this move '
            'begins. We couldn’t find a short transition between them.',
        confirmLabel: 'OK',
        icon: Icons.route_outlined,
        showCancelAction: false,
      ),
    );
    return false;
  }

  final bridgeCount = plan.bridgeAnimations.length;
  final connectionText = bridgeCount == 1
      ? 'one move that can connect them smoothly'
      : '$bridgeCount moves that can connect them smoothly';
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.black.withValues(alpha: AppOpacity.barrier),
    builder: (_) => AppConfirmationDialog(
      title: 'Connect these moves?',
      message:
          'Your last move ends in a different position than '
          '“${selectedAnimation.title}” begins. We found $connectionText.',
      confirmLabel: 'Connect',
      icon: Icons.route_rounded,
    ),
  );

  return confirmed == true;
}
