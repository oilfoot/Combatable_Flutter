import 'package:flutter/material.dart';

import 'controllers/sequence_controller.dart';
import 'screens/sequence_builder_screen.dart';
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
      title: 'Unity Sequence Prototype',
      theme: ThemeData.dark(),
      home: SequenceBuilderScreen(
        unityService: unityService,
        sequenceController: sequenceController,
      ),
    );
  }
}
