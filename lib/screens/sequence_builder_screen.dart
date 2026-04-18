import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../controllers/sequence_controller.dart';
import '../widgets/animation_info_sheet.dart';
import '../widgets/animation_library_card.dart';

class SequenceBuilderScreen extends StatefulWidget {
  const SequenceBuilderScreen({
    super.key,
    required this.sequenceController,
    required this.libraryController,
    required this.onBuildUnitySequence,
  });

  final SequenceController sequenceController;
  final LibraryController libraryController;
  final Future<void> Function() onBuildUnitySequence;

  @override
  State<SequenceBuilderScreen> createState() => _SequenceBuilderScreenState();
}

class _SequenceBuilderScreenState extends State<SequenceBuilderScreen> {
  late final TextEditingController _sequenceNameController;

  @override
  void initState() {
    super.initState();
    _sequenceNameController = TextEditingController(
      text: widget.sequenceController.sequenceName,
    );

    widget.sequenceController.addListener(_onControllerChanged);
    widget.libraryController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.sequenceController.removeListener(_onControllerChanged);
    widget.libraryController.removeListener(_onControllerChanged);
    _sequenceNameController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_sequenceNameController.text !=
        widget.sequenceController.sequenceName) {
      _sequenceNameController.text = widget.sequenceController.sequenceName;
      _sequenceNameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _sequenceNameController.text.length),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showAnimationInfo(LibraryDisplayItem entry) async {
    await AnimationInfoSheet.show(
      context,
      item: entry.item,
      isDownloaded: entry.isInstalled,
      isDownloading: entry.isDownloading,
      buttonText: widget.libraryController.getPrimaryActionLabel(entry),
      onPrimaryAction: () async {
        try {
          await widget.libraryController.performPrimaryAction(entry);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add ${entry.item.title}: $e')),
          );
        }
      },
    );
  }

  Future<void> _handlePrimaryAction(LibraryDisplayItem entry) async {
    try {
      await widget.libraryController.performPrimaryAction(entry);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add ${entry.item.title}: $e')),
      );
    }
  }

  Widget _buildRecommendedRow(List<LibraryDisplayItem> items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        alignment: Alignment.center,
        color: Colors.black12,
        child: const Text('No valid next animations available'),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final entry = items[index];

        return AnimationLibraryCard(
          item: entry.item,
          isDownloaded: entry.isInstalled,
          isDownloading: entry.isDownloading,
          showStatus: entry.isRemote,
          buttonText: widget.libraryController.getPrimaryActionLabel(entry),
          onTap: () => _showAnimationInfo(entry),
          onPrimaryAction: () => _handlePrimaryAction(entry),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sequence = widget.sequenceController;
    final library = widget.libraryController;
    final remote = library.remoteAddressablesService;

    final recommendedItems = library.recommendedNextItems;

    return Scaffold(
      appBar: AppBar(title: const Text('Sequence Builder')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _sequenceNameController,
                decoration: const InputDecoration(
                  labelText: 'Sequence name',
                  border: OutlineInputBorder(),
                ),
                onChanged: sequence.setSequenceName,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onBuildUnitySequence,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Build Unity Sequence',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => sequence.loadQuickTestData(
                      library.allItems.map((e) => e.item).toList(),
                    ),
                    child: const Text('Quick Test'),
                  ),
                  ElevatedButton(
                    onPressed: sequence.clearAnimations,
                    child: const Text('Clear List'),
                  ),
                  ElevatedButton(
                    onPressed: remote.isInitializing
                        ? null
                        : library.refreshLibrary,
                    child: Text(
                      remote.isInitializing
                          ? 'Refreshing...'
                          : 'Refresh Library',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                sequence.requiredNextStartPosition == null
                    ? 'Next position: Any'
                    : 'Required next start: ${sequence.requiredNextStartPosition}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Recommended Next Animations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: _buildRecommendedRow(recommendedItems),
              ),
              const SizedBox(height: 12),
              const Text(
                'Library Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.black26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(remote.status, style: const TextStyle(fontSize: 12)),
                    if (remote.addressablesDirPath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Local folder:\n${remote.addressablesDirPath}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (remote.catalogPath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Catalog path:\n${remote.catalogPath}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Current Sequence',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.black26,
                child: sequence.selectedAnimations.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('No animations selected yet'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sequence.selectedAnimations.length,
                        itemBuilder: (context, index) {
                          final item = sequence.selectedAnimations[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Text('${index + 1}'),
                              title: Text(item.title),
                              subtitle: Text(
                                '${item.animationName}  •  ${item.startPosition} -> ${item.endPosition}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    sequence.removeAnimationAt(index),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
