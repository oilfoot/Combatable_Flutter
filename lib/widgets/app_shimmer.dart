import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final travel = -1.8 + (_controller.value * 3.6);
        return ShaderMask(
          // `srcIn` uses the child only as a shape mask. Unlike `srcATop`, it
          // does not preserve the opaque white placeholder color, which would
          // make loading previews flash as solid white cards.
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(travel - 1, 0),
              end: Alignment(travel + 1, 0),
              colors: [
                AppColors.textPrimary.withValues(alpha: AppOpacity.faint),
                AppColors.textPrimary.withValues(alpha: AppOpacity.muted),
                AppColors.textPrimary.withValues(alpha: AppOpacity.faint),
              ],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}
