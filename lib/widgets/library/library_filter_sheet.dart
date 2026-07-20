import 'package:flutter/material.dart';

import '../../controllers/library_controller.dart';
import '../../theme/app_theme.dart';

class LibraryFilterSelection {
  LibraryFilterSelection({
    this.downloadedOnly = false,
    this.bookmarkedOnly = false,
    this.startPosition,
    this.endPosition,
    Set<String> tags = const {},
  }) : tags = Set.unmodifiable(tags);

  final bool downloadedOnly;
  final bool bookmarkedOnly;
  final String? startPosition;
  final String? endPosition;
  final Set<String> tags;

  int get activeCount =>
      (downloadedOnly ? 1 : 0) +
      (bookmarkedOnly ? 1 : 0) +
      (startPosition == null ? 0 : 1) +
      (endPosition == null ? 0 : 1) +
      tags.length;
}

Future<void> showLibraryFilterSheet(
  BuildContext context, {
  required LibraryFilterSelection initialSelection,
  required List<LibraryDisplayItem> allItems,
  required ValueChanged<LibraryFilterSelection> onChanged,
}) async {
  var downloadedOnly = initialSelection.downloadedOnly;
  var bookmarkedOnly = initialSelection.bookmarkedOnly;
  var startPosition = initialSelection.startPosition;
  var endPosition = initialSelection.endPosition;
  final selectedTags = initialSelection.tags.toSet();

  final startPositions = _uniqueSorted(
    allItems.map((entry) => entry.item.startPosition),
  );
  final endPositions = _uniqueSorted(
    allItems.map((entry) => entry.item.endPosition),
  );
  final tags = _uniqueSorted(allItems.expand((entry) => entry.item.tags));

  var startQuery = '';
  var endQuery = '';
  var tagQuery = '';

  void emitSelection() {
    onChanged(
      LibraryFilterSelection(
        downloadedOnly: downloadedOnly,
        bookmarkedOnly: bookmarkedOnly,
        startPosition: startPosition,
        endPosition: endPosition,
        tags: selectedTags,
      ),
    );
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.elevatedSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.panel)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final visibleStartPositions = _matching(startPositions, startQuery);
          final visibleEndPositions = _matching(endPositions, endQuery);
          final visibleTags = _matching(tags, tagQuery);

          void update(VoidCallback mutation) {
            setSheetState(mutation);
            emitSelection();
          }

          return SafeArea(
            top: false,
            child: FractionallySizedBox(
              heightFactor: 0.88,
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  const _SheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filter animations',
                            style: AppTypography.sectionTitle,
                          ),
                        ),
                        TextButton(
                          onPressed: () => update(() {
                            downloadedOnly = false;
                            bookmarkedOnly = false;
                            startPosition = null;
                            endPosition = null;
                            selectedTags.clear();
                          }),
                          child: const Text('Clear'),
                        ),
                        IconButton(
                          tooltip: 'Close filters',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        MediaQuery.viewInsetsOf(context).bottom +
                            AppSpacing.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FilterToggle(
                            label: 'Downloaded',
                            icon: Icons.download_done_rounded,
                            selected: downloadedOnly,
                            onTap: () =>
                                update(() => downloadedOnly = !downloadedOnly),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _FilterToggle(
                            label: 'Bookmarked',
                            icon: Icons.bookmark_rounded,
                            selected: bookmarkedOnly,
                            onTap: () =>
                                update(() => bookmarkedOnly = !bookmarkedOnly),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const Text(
                            'Start position',
                            style: AppTypography.componentTitle,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _FilterSearchField(
                            hintText: 'Find a start position',
                            onChanged: (value) =>
                                setSheetState(() => startQuery = value),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _SingleChoiceSelector(
                            values: visibleStartPositions,
                            selectedValue: startPosition,
                            showAny: startQuery.trim().isEmpty,
                            onSelected: (value) =>
                                update(() => startPosition = value),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const Text(
                            'End position',
                            style: AppTypography.componentTitle,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _FilterSearchField(
                            hintText: 'Find an end position',
                            onChanged: (value) =>
                                setSheetState(() => endQuery = value),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _SingleChoiceSelector(
                            values: visibleEndPositions,
                            selectedValue: endPosition,
                            showAny: endQuery.trim().isEmpty,
                            onSelected: (value) =>
                                update(() => endPosition = value),
                          ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xl),
                            const Text(
                              'Tags',
                              style: AppTypography.componentTitle,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _FilterSearchField(
                              hintText: 'Find a tag',
                              onChanged: (value) =>
                                  setSheetState(() => tagQuery = value),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _MultiChoiceSelector(
                              values: visibleTags,
                              selectedValues: selectedTags,
                              onToggle: (value) => update(() {
                                if (!selectedTags.add(value)) {
                                  selectedTags.remove(value);
                                }
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

List<String> _uniqueSorted(Iterable<String> source) {
  final values = source
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return values;
}

List<String> _matching(List<String> values, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return values;
  return values
      .where((value) => value.toLowerCase().contains(normalized))
      .toList(growable: false);
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.textSecondary,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    );
  }
}

class _FilterSearchField extends StatelessWidget {
  const _FilterSearchField({required this.hintText, required this.onChanged});

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        onChanged: onChanged,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            borderSide: const BorderSide(color: AppColors.borderSubtle),
          ),
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
    );
  }
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.22)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: selected
                    ? AppColors.accentSoft
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(label, style: AppTypography.controlLabel)),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 21,
                color: selected
                    ? AppColors.accentSoft
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleChoiceSelector extends StatelessWidget {
  const _SingleChoiceSelector({
    required this.values,
    required this.selectedValue,
    required this.showAny,
    required this.onSelected,
  });

  final List<String> values;
  final String? selectedValue;
  final bool showAny;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (showAny)
          _ChoiceChip(
            label: 'Any',
            selected: selectedValue == null,
            onTap: () => onSelected(null),
          ),
        ...values.map(
          (value) => _ChoiceChip(
            label: value,
            selected: selectedValue == value,
            onTap: () => onSelected(value),
          ),
        ),
      ],
    );
  }
}

class _MultiChoiceSelector extends StatelessWidget {
  const _MultiChoiceSelector({
    required this.values,
    required this.selectedValues,
    required this.onToggle,
  });

  final List<String> values;
  final Set<String> selectedValues;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: values
          .map(
            (value) => _ChoiceChip(
              label: value,
              selected: selectedValues.contains(value),
              onTap: () => onToggle(value),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.borderSubtle,
            ),
          ),
          child: Text(label, style: AppTypography.label),
        ),
      ),
    );
  }
}
