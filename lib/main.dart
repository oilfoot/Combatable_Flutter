import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'controllers/sequence_controller.dart';
import 'services/unity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final unityService = UnityService();
  await unityService.initialize();

  final sequenceController = SequenceController(unityService: unityService);

  runApp(
    MyApp(unityService: unityService, sequenceController: sequenceController),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.unityService,
    required this.sequenceController,
  });

  final UnityService unityService;
  final SequenceController sequenceController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Combatable Prototype',
      theme: ThemeData.dark(),
      home: AppShell(
        unityService: unityService,
        sequenceController: sequenceController,
      ),
    );
  }
}
