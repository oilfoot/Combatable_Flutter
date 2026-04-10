import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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

  String _addressablesStatus = 'Not downloaded yet.';
  String? _addressablesDirPath;
  String? _catalogPath;
  bool _isDownloadingAddressables = false;
  bool _isSendingCatalog = false;

  final List<AnimationLibraryItem> _downloadedAddressableItems = [];

  static const List<String> _addressableFiles = <String>[
    'catalog.hash',
    'catalog.bin',
    'remotegroup_assets_all_32ac13a254b1b106f3bf8005a358bfca.bundle',
    'addressables_manifest.json',
  ];

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

  List<AnimationLibraryItem> _parseManifestItems(String jsonString) {
    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      throw Exception('Manifest is not a JSON array.');
    }

    return decoded.map<AnimationLibraryItem>((entry) {
      if (entry is! Map<String, dynamic>) {
        throw Exception('Manifest entry is not a JSON object.');
      }

      return AnimationLibraryItem(
        title: (entry['title'] ?? '').toString(),
        animationName: (entry['animationName'] ?? '').toString(),
        startPosition: (entry['startPosition'] ?? '').toString(),
        endPosition: (entry['endPosition'] ?? '').toString(),
      );
    }).toList();
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
    );
  }

  Future<void> _downloadAddressables() async {
    if (_isDownloadingAddressables) return;

    setState(() {
      _isDownloadingAddressables = true;
      _addressablesStatus = 'Downloading Addressables...';
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final addressablesDir = Directory('${appDir.path}/addressables');

      if (!await addressablesDir.exists()) {
        await addressablesDir.create(recursive: true);
      }

      for (final fileName in _addressableFiles) {
        final localFile = File('${addressablesDir.path}/$fileName');
        final ref = FirebaseStorage.instance.ref('addressables/iOS/$fileName');
        await ref.writeToFile(localFile);
      }

      final manifestFile = File(
        '${addressablesDir.path}/addressables_manifest.json',
      );

      if (!await manifestFile.exists()) {
        throw Exception('Manifest file was not downloaded.');
      }

      final manifestContent = await manifestFile.readAsString();
      final parsedItems = _parseManifestItems(manifestContent);

      final catalogPath = '${addressablesDir.path}/catalog.bin';

      setState(() {
        _addressablesDirPath = addressablesDir.path;
        _catalogPath = catalogPath;
        _downloadedAddressableItems
          ..clear()
          ..addAll(parsedItems);
        _addressablesStatus =
            'Addressables ready.\n'
            'Folder: ${addressablesDir.path}\n'
            'Catalog: $catalogPath\n'
            'Loaded ${parsedItems.length} item(s) from manifest.';
      });
    } catch (e) {
      setState(() {
        _addressablesStatus = 'Download failed:\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingAddressables = false;
        });
      }
    }
  }

  Future<void> _loadCatalogInUnity() async {
    if (_isSendingCatalog) return;

    if (_catalogPath == null || _catalogPath!.isEmpty) {
      setState(() {
        _addressablesStatus =
            'No catalog path available yet. Download Addressables first.';
      });
      return;
    }

    setState(() {
      _isSendingCatalog = true;
      _addressablesStatus = 'Sending catalog path to Unity...';
    });

    try {
      await widget.unityService.resumeUnity();

      await widget.unityService.loadLocalAddressablesCatalog(
        catalogPath: _catalogPath!,
      );

      setState(() {
        _addressablesStatus =
            'Catalog path sent to Unity.\nCatalog: $_catalogPath';
      });
    } catch (e) {
      setState(() {
        _addressablesStatus = 'Failed to send catalog to Unity:\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCatalog = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.sequenceController;

    final availableMockItems = controller.getAvailableLibraryItems(
      mockAnimationLibrary,
    );

    final availableDownloadedItems = controller.getAvailableLibraryItems(
      _downloadedAddressableItems,
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
              Row(
                children: [
                  const Text(
                    'Animation Library',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (controller.requiredNextStartPosition != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Need: ${controller.requiredNextStartPosition}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: _buildLibraryRow(
                  items: availableMockItems,
                  emptyText: 'No matching follow-up animations available',
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
                    onPressed: _isDownloadingAddressables
                        ? null
                        : _downloadAddressables,
                    child: Text(
                      _isDownloadingAddressables
                          ? 'Downloading...'
                          : 'Download Addressables',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isSendingCatalog ? null : _loadCatalogInUnity,
                    child: Text(
                      _isSendingCatalog
                          ? 'Sending to Unity...'
                          : 'Load Catalog in Unity',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Downloaded Addressables',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: _buildLibraryRow(
                  items: availableDownloadedItems,
                  emptyText:
                      'No downloaded remote items yet. Tap "Download Addressables".',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Addressables Test',
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
                    Text(
                      _addressablesStatus,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_addressablesDirPath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Local folder:\n$_addressablesDirPath',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (_catalogPath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Catalog path:\n$_catalogPath',
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
    );
  }
}
