import 'package:flutter/material.dart';

import '../controllers/sequence_controller.dart';
import '../data/mock_animation_library.dart';
import '../models/animation_library_item.dart';
import '../services/remote_addressables_service.dart';

class SequenceBuilderScreen extends StatefulWidget {
  const SequenceBuilderScreen({
    super.key,
    required this.sequenceController,
    required this.remoteAddressablesService,
    required this.onBuildUnitySequence,
  });

  final SequenceController sequenceController;
  final RemoteAddressablesService remoteAddressablesService;
  final Future<void> Function() onBuildUnitySequence;

  @override
  State<SequenceBuilderScreen> createState() => _SequenceBuilderScreenState();
}

class _SequenceBuilderScreenState extends State<SequenceBuilderScreen> {
  late final TextEditingController _sequenceNameController;
  late final RemoteAddressablesService _remoteAddressablesService;

  @override
  void initState() {
    super.initState();

    _sequenceNameController = TextEditingController(
      text: widget.sequenceController.sequenceName,
    );

    _remoteAddressablesService = widget.remoteAddressablesService;

    widget.sequenceController.addListener(_onControllerChanged);
    _remoteAddressablesService.addListener(_onRemoteChanged);
  }

  @override
  void dispose() {
    widget.sequenceController.removeListener(_onControllerChanged);
    _remoteAddressablesService.removeListener(_onRemoteChanged);
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

    if (mounted) setState(() {});
  }

  void _onRemoteChanged() {
    if (mounted) setState(() {});
  }

  void _addLibraryItem(AnimationLibraryItem item) {
    widget.sequenceController.addAnimationItem(item);
  }

  Widget _buildLibraryRow({
    required List<AnimationLibraryItem> items,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        alignment: Alignment.center,
        color: Colors.black12,
        child: Text(emptyText),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return SizedBox(
          width: 240,
          child: Card(
            margin: const EdgeInsets.only(right: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text('Clip: ${item.animationName}'),
                  const SizedBox(height: 4),
                  Text('Start: ${item.startPosition}'),
                  Text('End: ${item.endPosition}'),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _addLibraryItem(item),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.sequenceController;
    final remote = _remoteAddressablesService;

    final availableMockItems = controller.getAvailableLibraryItems(
      mockAnimationLibrary,
    );

    final availableDownloadedItems = controller.getAvailableLibraryItems(
      remote.downloadedItems,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sequence Builder')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Sequence Name
              TextField(
                controller: _sequenceNameController,
                decoration: const InputDecoration(
                  labelText: 'Sequence name',
                  border: OutlineInputBorder(),
                ),
                onChanged: controller.setSequenceName,
              ),

              const SizedBox(height: 12),

              /// 🔥 BUILD BUTTON (MAIN FEATURE)
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

              /// Local Library
              const Text(
                'Animation Library',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: _buildLibraryRow(
                  items: availableMockItems,
                  emptyText: 'No matching animations',
                ),
              ),

              const SizedBox(height: 12),

              /// Actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () =>
                        controller.loadQuickTestData(mockAnimationLibrary),
                    child: const Text('Quick Test'),
                  ),
                  ElevatedButton(
                    onPressed: controller.clearAnimations,
                    child: const Text('Clear List'),
                  ),
                  ElevatedButton(
                    onPressed: remote.isDownloading
                        ? null
                        : remote.downloadAddressables,
                    child: Text(
                      remote.isDownloading
                          ? 'Downloading...'
                          : 'Download Addressables',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// Downloaded Library
              const Text(
                'Downloaded Addressables',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: _buildLibraryRow(
                  items: availableDownloadedItems,
                  emptyText: 'No downloaded animations',
                ),
              ),

              const SizedBox(height: 12),

              /// Status
              const Text(
                'Addressables Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.black26,
                child: Text(
                  remote.status,
                  style: const TextStyle(fontSize: 12),
                ),
              ),

              const SizedBox(height: 12),

              /// Current Sequence
              const Text(
                'Current Sequence',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.black26,
                child: controller.selectedAnimations.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No animations selected yet'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controller.selectedAnimations.length,
                        itemBuilder: (context, index) {
                          final item = controller.selectedAnimations[index];

                          return ListTile(
                            title: Text(item.title),
                            subtitle: Text(item.animationName),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  controller.removeAnimationAt(index),
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
