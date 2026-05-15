import 'dart:ui';

import 'package:flutter/material.dart';

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.isExpanded,
    required this.onNavPressed,
    required this.onTap,
  });

  final int currentIndex;
  final bool isExpanded;
  final VoidCallback onNavPressed;
  final Future<void> Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isExpanded ? 1.0 : 0.82,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isExpanded ? 0.18 : 0.13),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(isExpanded ? 0.32 : 0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isExpanded ? 0.22 : 0.14),
                  blurRadius: isExpanded ? 26 : 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavButton(
                  icon: Icons.home_rounded,
                  isSelected: currentIndex == 0,
                  onPressStart: onNavPressed,
                  onTap: () => onTap(0),
                ),
                _NavButton(
                  icon: Icons.grid_view_rounded,
                  isSelected: currentIndex == 1,
                  onPressStart: onNavPressed,
                  onTap: () => onTap(1),
                ),
                _NavButton(
                  icon: Icons.deployed_code,
                  isSelected: currentIndex == 2,
                  onPressStart: onNavPressed,
                  onTap: () => onTap(2),
                ),
                _NavButton(
                  icon: Icons.playlist_add_rounded,
                  isSelected: currentIndex == 3,
                  onPressStart: onNavPressed,
                  onTap: () => onTap(3),
                ),
                _NavButton(
                  icon: Icons.person_rounded,
                  isSelected: currentIndex == 4,
                  onPressStart: onNavPressed,
                  onTap: () => onTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.isSelected,
    required this.onPressStart,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressStart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onPressStart(),
      onTap: onTap,
      child: SizedBox(
        width: 52,
        height: 46,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(23),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 27,
              color: isSelected ? Colors.black : Colors.black.withOpacity(0.72),
            ),
          ),
        ),
      ),
    );
  }
}
