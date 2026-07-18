part of '../../screens/sequence_builder_screen.dart';

class _TimelineActions extends StatelessWidget {
  const _TimelineActions({
    required this.canUndo,
    required this.canRedo,
    required this.canClear,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
  });

  final bool canUndo;
  final bool canRedo;
  final bool canClear;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: AppColors.borderSubtle),
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
          Container(width: 1, height: 20, color: AppColors.borderSubtle),
          _HistoryIconButton(
            tooltip: 'Redo',
            icon: Icons.redo_rounded,
            enabled: canRedo,
            onPressed: onRedo,
          ),
          Container(width: 1, height: 20, color: AppColors.borderSubtle),
          _HistoryIconButton(
            tooltip: 'Clear all',
            icon: Icons.delete_outline_rounded,
            enabled: canClear,
            onPressed: onClear,
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
      icon: Icon(icon, size: 20),
      color: AppColors.accentSoft,
      disabledColor: AppColors.textDisabled,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 42),
      splashRadius: 21,
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

  Future<void> _openSequenceDetails(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.black.withValues(alpha: AppOpacity.barrier),
      builder: (_) => _SequenceDetailsSheet(
        initialName: sequenceNameController.text,
        onSave: (name) {
          final normalizedName = name.trim().isEmpty
              ? 'New Sequence'
              : name.trim();
          sequenceNameController.value = TextEditingValue(
            text: normalizedName,
            selection: TextSelection.collapsed(offset: normalizedName.length),
          );
          onNameChanged(normalizedName);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sequence Builder',
                    style: AppTypography.screenTitle,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Name and save sequence',
                    onPressed: () => _openSequenceDetails(context),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                    color: AppColors.accentSoft,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onBuildUnitySequence,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Build Sequence', style: AppTypography.button),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const Expanded(
                  child: Text('Timeline', style: AppTypography.sectionTitle),
                ),
                _TimelineActions(
                  canUndo: canUndo,
                  canRedo: canRedo,
                  canClear: canClear,
                  onUndo: onUndo,
                  onRedo: onRedo,
                  onClear: onClear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SequenceDetailsSheet extends StatefulWidget {
  const _SequenceDetailsSheet({
    required this.initialName,
    required this.onSave,
  });

  final String initialName;
  final ValueChanged<String> onSave;

  @override
  State<_SequenceDetailsSheet> createState() => _SequenceDetailsSheetState();
}

class _SequenceDetailsSheetState extends State<_SequenceDetailsSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(_nameController.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.panel),
          ),
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textDisabled,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sequence details',
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Sequence name',
                  prefixIcon: const Icon(Icons.edit_outlined, size: 19),
                  filled: true,
                  fillColor: AppColors.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    borderSide: const BorderSide(color: AppColors.accentSoft),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 19),
                  label: const Text('Save sequence'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
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
