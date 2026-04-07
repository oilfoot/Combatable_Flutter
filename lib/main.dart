import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:unity_kit/unity_kit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Unity Sequence Prototype',
      theme: ThemeData.dark(),
      home: const UnitySequencePrototypeScreen(),
    );
  }
}

class UnitySequencePrototypeScreen extends StatefulWidget {
  const UnitySequencePrototypeScreen({super.key});

  @override
  State<UnitySequencePrototypeScreen> createState() =>
      _UnitySequencePrototypeScreenState();
}

class _UnitySequencePrototypeScreenState
    extends State<UnitySequencePrototypeScreen> {
  late final UnityBridge _bridge;

  final TextEditingController _sequenceNameController = TextEditingController(
    text: 'My Test Sequence',
  );
  final TextEditingController _animationNameController =
      TextEditingController();

  final List<String> _animations = <String>[];
  final List<String> _logs = <String>[];

  bool _unityReady = false;

  StreamSubscription? _messageSub;
  StreamSubscription? _sceneSub;

  @override
  void initState() {
    super.initState();
    _initUnity();
  }

  Future<void> _initUnity() async {
    _bridge = UnityBridgeImpl(platform: UnityKitPlatform.instance);
    await _bridge.initialize();

    _messageSub = _bridge.messageStream.listen((message) {
      _addLog(
        "Flutter received from Unity => type=${message.type}, data=${message.data}",
      );
    });

    _sceneSub = _bridge.sceneStream.listen((scene) {
      _addLog("Scene loaded => ${scene.name}");
    });

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _sceneSub?.cancel();
    _sequenceNameController.dispose();
    _animationNameController.dispose();
    _bridge.dispose();
    super.dispose();
  }

  void _addLog(String text) {
    developer.log(text);

    if (!mounted) return;

    setState(() {
      _logs.insert(0, text);
      if (_logs.length > 40) {
        _logs.removeLast();
      }
    });
  }

  void _addAnimation() {
    final value = _animationNameController.text.trim();

    if (value.isEmpty) {
      _addLog("Animation name is empty. Nothing added.");
      return;
    }

    setState(() {
      _animations.add(value);
      _animationNameController.clear();
    });

    _addLog("Added animation: $value");
  }

  void _removeAnimationAt(int index) {
    if (index < 0 || index >= _animations.length) return;

    final removed = _animations[index];

    setState(() {
      _animations.removeAt(index);
    });

    _addLog("Removed animation: $removed");
  }

  void _clearAnimations() {
    setState(() {
      _animations.clear();
    });

    _addLog("Cleared animation list.");
  }

  Future<void> _sendSequenceToUnity() async {
    final sequenceName = _sequenceNameController.text.trim().isEmpty
        ? 'New Sequence'
        : _sequenceNameController.text.trim();

    final payload = <String, dynamic>{
      'sequenceName': sequenceName,
      'animations': List<String>.from(_animations),
    };

    final msg = UnityMessage.to(
      'FlutterSequenceReceiver',
      'SetSequence',
      payload,
    );

    await _bridge.send(msg);

    _addLog(
      "Sent sequence '$sequenceName' with ${_animations.length} animation(s) to Unity.",
    );
  }

  void _addQuickTestData() {
    setState(() {
      _sequenceNameController.text = 'Prototype Sequence';
      _animations
        ..clear()
        ..addAll(['Kick2', 'Seq1', 'Kick2']);
    });

    _addLog("Inserted quick test data.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unity Sequence Prototype')),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: UnityView(
              bridge: _bridge,
              config: const UnityConfig(sceneName: 'MainScene'),
              placeholder: const Center(child: CircularProgressIndicator()),
              onReady: (bridge) {
                setState(() {
                  _unityReady = true;
                });
                _addLog("Unity onReady fired");
              },
              onMessage: (message) {
                _addLog(
                  "onMessage => type=${message.type}, data=${message.data}",
                );
              },
              onSceneLoaded: (scene) {
                _addLog("onSceneLoaded => ${scene.name}");
              },
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _unityReady ? 'Unity ready' : 'Unity not ready',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sequenceNameController,
                    decoration: const InputDecoration(
                      labelText: 'Sequence name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _animationNameController,
                          decoration: const InputDecoration(
                            labelText: 'Animation name',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addAnimation(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addAnimation,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _addQuickTestData,
                        child: const Text('Quick Test'),
                      ),
                      ElevatedButton(
                        onPressed: _clearAnimations,
                        child: const Text('Clear List'),
                      ),
                      ElevatedButton(
                        onPressed: _unityReady && _animations.isNotEmpty
                            ? _sendSequenceToUnity
                            : null,
                        child: const Text('Send To Unity'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Animations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: Colors.black26,
                      child: _animations.isEmpty
                          ? const Center(child: Text('No animations added yet'))
                          : ListView.builder(
                              itemCount: _animations.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    leading: Text('${index + 1}'),
                                    title: Text(_animations[index]),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          _removeAnimationAt(index),
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
                    height: 120,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: Colors.black26,
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _logs[index],
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
