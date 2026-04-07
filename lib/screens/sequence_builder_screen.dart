import 'package:flutter/material.dart';
import 'package:unity_kit/unity_kit.dart';

import '../controllers/sequence_controller.dart';
import '../data/mock_animation_library.dart';
import '../models/animation_library_item.dart';
import '../services/unity_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final controller = widget.sequenceController;

    return Scaffold(
      appBar: AppBar(title: const Text('Unity Sequence Prototype')),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: UnityView(
              bridge: widget.unityService.bridge,
              config: const UnityConfig(sceneName: 'MainScene'),
              placeholder: const Center(child: CircularProgressIndicator()),
              onReady: (bridge) {
                widget.unityService.markUnityReady();
                setState(() {});
              },
              onMessage: (message) {
                setState(() {});
              },
              onSceneLoaded: (scene) {
                setState(() {});
              },
            ),
          ),
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.isUnityReady ? 'Unity ready' : 'Unity not ready',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sequenceNameController,
                    decoration: const InputDecoration(
                      labelText: 'Sequence name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: controller.setSequenceName,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Animation Library',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: mockAnimationLibrary.length,
                      itemBuilder: (context, index) {
                        final item = mockAnimationLibrary[index];

                        return SizedBox(
                          width: 180,
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
                                    item.animationName,
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
                        onPressed:
                            controller.isUnityReady &&
                                controller.selectedAnimations.isNotEmpty
                            ? () async {
                                await controller.sendToUnity();
                              }
                            : null,
                        child: const Text('Send To Unity'),
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
                          ? const Center(
                              child: Text('No animations selected yet'),
                            )
                          : ListView.builder(
                              itemCount: controller.selectedAnimations.length,
                              itemBuilder: (context, index) {
                                final item =
                                    controller.selectedAnimations[index];

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    leading: Text('${index + 1}'),
                                    title: Text(item.title),
                                    subtitle: Text(item.animationName),
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
          ),
        ],
      ),
    );
  }
}
