part of '../../screens/sequence_builder_screen.dart';

class _TimelineHistoryControls extends StatelessWidget {
  const _TimelineHistoryControls({
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HistoryIconButton(
            tooltip: 'Undo',
            icon: Icons.undo_rounded,
            enabled: canUndo,
            onPressed: onUndo,
          ),
          Container(
            width: 1,
            height: 16,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          _HistoryIconButton(
            tooltip: 'Redo',
            icon: Icons.redo_rounded,
            enabled: canRedo,
            onPressed: onRedo,
          ),
        ],
      ),
    );
  }
}

class _HistoryIconButton extends StatelessWidget {
  const _HistoryIconButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 17),
      color: const Color(0xFFC8A7FF),
      disabledColor: Colors.white.withValues(alpha: 0.18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 32),
      splashRadius: 17,
    );
  }
}

class _SequenceHeader extends StatelessWidget {
  const _SequenceHeader({
    required this.sequenceNameController,
    required this.onNameChanged,
    required this.onBuildUnitySequence,
    required this.canUndo,
    required this.canRedo,
    required this.canClear,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
  });

  final TextEditingController sequenceNameController;
  final ValueChanged<String> onNameChanged;
  final Future<void> Function() onBuildUnitySequence;
  final bool canUndo;
  final bool canRedo;
  final bool canClear;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          const Text(
            'Sequence Builder',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.045),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.09)),
                  ),
                  child: TextField(
                    controller: sequenceNameController,
                    onChanged: onNameChanged,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Sequence name',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      suffixIcon: const Icon(Icons.edit_outlined, size: 17),
                      contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC8A7FF),
                    side: BorderSide(
                      color: const Color(0xFFC8A7FF).withOpacity(0.48),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onBuildUnitySequence,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text(
                'Build Unity Sequence',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8F55FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Timeline',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                _TimelineHistoryControls(
                  canUndo: canUndo,
                  canRedo: canRedo,
                  onUndo: onUndo,
                  onRedo: onRedo,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: canClear ? onClear : null,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Clear All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC8A7FF),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.20,
                      ),
                      backgroundColor: const Color(
                        0xFF8F55FF,
                      ).withValues(alpha: canClear ? 0.07 : 0.015),
                      side: BorderSide(
                        color: canClear
                            ? const Color(0xFFC8A7FF).withValues(alpha: 0.26)
                            : Colors.white.withValues(alpha: 0.07),
                      ),
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      shape: const StadiumBorder(),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
