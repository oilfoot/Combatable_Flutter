import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<String> _ensureAddressablesDownloaded() async {
    final appDir = await getApplicationDocumentsDirectory();
    final addressablesDir = Directory('${appDir.path}/addressables');

    if (!await addressablesDir.exists()) {
      await addressablesDir.create(recursive: true);
    }

    final files = <String>[
      'catalog_0.1.0.hash',
      'catalog_0.1.0.bin',
      'remotegroup_assets_all_c8ca3e9e6d0cf52e5ccc935ebcb07b4f.bundle',
    ];

    final downloadedFiles = <String>[];

    for (final fileName in files) {
      final localFile = File('${addressablesDir.path}/$fileName');

      if (!await localFile.exists()) {
        final ref = FirebaseStorage.instance.ref('addressables/iOS/$fileName');
        await ref.writeToFile(localFile);
      }

      downloadedFiles.add(localFile.path);
    }

    return '''
Addressables folder:
${addressablesDir.path}

Files:
${downloadedFiles.join('\n')}
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: FutureBuilder<String>(
            future: _ensureAddressablesDownloaded(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.data ?? 'No data.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
