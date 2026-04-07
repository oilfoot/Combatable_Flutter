import 'package:flutter/material.dart';

import '../controllers/sequence_controller.dart';
import '../data/mock_animation_library.dart';
import '../models/animation_library_item.dart';
import '../services/unity_service.dart';
import 'unity_preview_screen.dart';

class SequenceBuilderScreen extends StatefulWidget {
  const SequenceBuilderScreen({
    super.key,
    required this.unityService,
    required this.sequenceController,
  });

  final UnityService unityService;
  final SequenceController sequenceController;

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
  }

  @override
  void dispose() {
    widget.sequenceController.removeListener(_onControllerChanged);
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

  void _addLibraryItem(AnimationLibraryItem item) {
    widget.sequenceController.addAnimationItem(item);
  }

  Future<void> _openUnityPreview() async {
    if (!widget.sequenceController.hasAnimations) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnityPreviewScreen(
          unityService: widget.unityService,
          sequenceController: widget.sequenceController,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.sequenceController;
    final availableItems = controller.getAvailableLibraryItems(
      mockAnimationLibrary,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sequence Builder')),
      body: Padding(
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
            Text(
              controller.selectedAnimations.isEmpty
                  ? 'Animation Library'
                  : 'Animation Library — only matches for start "${controller.requiredNextStartPosition}"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: availableItems.isEmpty
                  ? Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      color: Colors.black12,
                      child: const Text(
                        'No matching follow-up animations available',
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: availableItems.length,
                      itemBuilder: (context, index) {
                        final item = availableItems[index];

                        return SizedBox(
                          width: 220,
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
                  onPressed: controller.hasAnimations
                      ? _openUnityPreview
                      : null,
                  child: const Text('Open Unity Preview'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Current Sequence',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.black26,
                child: controller.selectedAnimations.isEmpty
                    ? const Center(child: Text('No animations selected yet'))
                    : ListView.builder(
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
            ),
            const SizedBox(height: 12),
            const Text(
              'Flutter logs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.black26,
                child: ListView.builder(
                  itemCount: controller.logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        controller.logs[index],
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
