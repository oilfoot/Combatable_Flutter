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

    if (mounted) {
      setState(() {});
    }
  }

  void _onRemoteChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _addLibraryItem(AnimationLibraryItem item) {
    widget.sequenceController.addAnimationItem(item);
  }

  Future<void> _handleRemoteItemTap(AnimationLibraryItem item) async {
    try {
      final isDownloaded = _remoteAddressablesService.isAnimationDownloaded(
        item.animationName,
      );

      if (!isDownloaded) {
        await _remoteAddressablesService.downloadAnimation(item.animationName);
      }

      _addLibraryItem(item);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download/add ${item.title}: $e')),
      );
    }
  }

  Widget _buildLibraryRow({
    required List<AnimationLibraryItem> items,
    required String emptyText,
    required bool useRemoteState,
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

        final isDownloaded = useRemoteState
            ? _remoteAddressablesService.isAnimationDownloaded(
                item.animationName,
              )
            : true;

        final isDownloading = useRemoteState
            ? _remoteAddressablesService.isAnimationDownloading(
                item.animationName,
              )
            : false;

        final buttonText = useRemoteState
            ? isDownloading
                  ? 'Downloading...'
                  : isDownloaded
                  ? 'Add'
                  : 'Download & Add'
            : 'Add';

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
                  Text(
                    'Clip: ${item.animationName}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Start: ${item.startPosition}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'End: ${item.endPosition}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  if (useRemoteState)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDownloaded
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isDownloaded ? 'Installed' : 'Not installed',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDownloaded
                              ? Colors.green.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isDownloading
                          ? null
                          : () async {
                              if (useRemoteState) {
                                await _handleRemoteItemTap(item);
                              } else {
                                _addLibraryItem(item);
                              }
                            },
                      child: Text(buttonText),
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

    final availableRemoteItems = controller.getAvailableLibraryItems(
      remote.availableItems,
    );

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
                onChanged: controller.setSequenceName,
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
                    onPressed: () =>
                        controller.loadQuickTestData(mockAnimationLibrary),
                    child: const Text('Quick Test'),
                  ),
                  ElevatedButton(
                    onPressed: controller.clearAnimations,
                    child: const Text('Clear List'),
                  ),
                  ElevatedButton(
                    onPressed: remote.isInitializing
                        ? null
                        : remote.refreshLibrary,
                    child: Text(
                      remote.isInitializing
                          ? 'Refreshing...'
                          : 'Refresh Remote Library',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Installed Mock Library',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: _buildLibraryRow(
                  items: availableMockItems,
                  emptyText: 'No matching follow-up animations available',
                  useRemoteState: false,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Remote Animation Library',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 210,
                child: _buildLibraryRow(
                  items: availableRemoteItems,
                  emptyText: remote.isInitializing
                      ? 'Loading remote library...'
                      : 'No remote animations available',
                  useRemoteState: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Addressables Status',
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
                child: controller.selectedAnimations.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('No animations selected yet'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controller.selectedAnimations.length,
                        itemBuilder: (context, index) {
                          final item = controller.selectedAnimations[index];

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
                                    controller.removeAnimationAt(index),
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
