import 'package:flutter/material.dart';

class AnimationPrimaryActionButton extends StatelessWidget {
  const AnimationPrimaryActionButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () async {
                await onPressed();
              },
        child: Text(label),
      ),
    );
  }
}
