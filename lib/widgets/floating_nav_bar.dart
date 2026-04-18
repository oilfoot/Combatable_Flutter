import 'dart:ui';
import 'package:flutter/material.dart';

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(Icons.home, 0),
              _item(Icons.playlist_add, 1),
              _item(Icons.view_in_ar, 2),
              _item(Icons.grid_view, 3),
              _item(Icons.person, 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(IconData icon, int index) {
    final isSelected = index == currentIndex;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: isSelected ? Colors.white : Colors.white70),
      ),
    );
  }
}
