import 'package:flutter/material.dart';

import 'controllers/sequence_controller.dart';
import 'screens/full_library_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sequence_builder_screen.dart';
import 'screens/unity_preview_screen.dart';
import 'services/unity_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.unityService,
    required this.sequenceController,
  });

  final UnityService unityService;
  final SequenceController sequenceController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      SequenceBuilderScreen(
        unityService: widget.unityService,
        sequenceController: widget.sequenceController,
      ),
      UnityPreviewScreen(
        unityService: widget.unityService,
        sequenceController: widget.sequenceController,
        embeddedInTab: true,
      ),
      const FullLibraryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) async {
          if (_currentIndex == 2 && index != 2) {
            await widget.unityService.pauseUnity();
          }

          if (index == 2) {
            await widget.unityService.preparePreview(
              sequenceName: widget.sequenceController.sequenceName,
              animations: widget.sequenceController.getAnimationNamesForUnity(),
            );
          }

          if (mounted) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.playlist_add_outlined),
            selectedIcon: Icon(Icons.playlist_add),
            label: 'Builder',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_in_ar_outlined),
            selectedIcon: Icon(Icons.view_in_ar),
            label: 'Unity',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
