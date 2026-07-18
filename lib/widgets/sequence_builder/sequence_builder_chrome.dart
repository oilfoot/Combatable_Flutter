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
      height: SequenceBuilderLayout.minimumControlTarget,
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
      constraints: const BoxConstraints.tightFor(
        width: SequenceBuilderLayout.minimumControlTarget,
        height: SequenceBuilderLayout.minimumControlTarget,
      ),
      splashRadius: 21,
    );
  }
}

class _SequenceHeader extends StatelessWidget {
  const _SequenceHeader({
    required this.sequenceNameController,
    required this.onNameChanged,
    required this.canSave,
    required this.onSaveSequence,
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
  final bool canSave;
  final Future<void> Function(String name) onSaveSequence;
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
        onSave: (name) async {
          final normalizedName = name.trim();
          sequenceNameController.value = TextEditingValue(
            text: normalizedName,
            selection: TextSelection.collapsed(offset: normalizedName.length),
          );
          onNameChanged(normalizedName);
          await onSaveSequence(normalizedName);
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
            height: SequenceBuilderLayout.minimumControlTarget,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sequence Builder',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.screenTitle,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                IconButton(
                  tooltip: canSave
                      ? 'Name and save sequence'
                      : 'Add at least 2 steps to save',
                  onPressed: canSave
                      ? () => _openSequenceDetails(context)
                      : null,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                  color: AppColors.accentSoft,
                  disabledColor: AppColors.textDisabled,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: SequenceBuilderLayout.minimumControlTarget,
                    height: SequenceBuilderLayout.minimumControlTarget,
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
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: SequenceBuilderLayout.primaryActionHeight,
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
            height: SequenceBuilderLayout.minimumControlTarget,
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
  final Future<void> Function(String name) onSave;

  @override
  State<_SequenceDetailsSheet> createState() => _SequenceDetailsSheetState();
}

class _SequenceDetailsSheetState extends State<_SequenceDetailsSheet> {
  late final TextEditingController _nameController;
  bool _isSaving = false;
  String? _saveError;

  bool get _hasValidName => _nameController.text.trim().isNotEmpty;

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

  Future<void> _save() async {
    if (!_hasValidName || _isSaving) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      await widget.onSave(_nameController.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'The sequence could not be saved. Please try again.';
      });
    }
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
                autofocus: true,
                enabled: !_isSaving,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _saveError = null),
                onSubmitted: (_) {
                  if (_hasValidName) _save();
                },
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
              if (_saveError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _saveError!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.destructiveSoft,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _hasValidName && !_isSaving ? _save : null,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : const Icon(Icons.bookmark_add_outlined, size: 19),
                  label: Text(_isSaving ? 'Saving...' : 'Save sequence'),
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
