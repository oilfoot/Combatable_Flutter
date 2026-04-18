import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'controllers/library_controller.dart';
import 'controllers/sequence_controller.dart';
import 'screens/full_library_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sequence_builder_screen.dart';
import 'screens/unity_preview_screen.dart';
import 'services/remote_addressables_service.dart';
import 'services/unity_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.unityService,
    required this.sequenceController,
  });

  final UnityService unityService;
  final SequenceController sequenceController;

  static const double floatingNavHorizontalPadding = 16;
  static const double floatingNavBottomSpacing = 8;
  static const double floatingNavExtraScrollSpace = 130;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 1;

  late final RemoteAddressablesService _remoteAddressablesService;
  late final LibraryController _libraryController;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _remoteAddressablesService = RemoteAddressablesService(
      unityService: widget.unityService,
    );

    _libraryController = LibraryController(
      sequenceController: widget.sequenceController,
      remoteAddressablesService: _remoteAddressablesService,
    );

    _remoteAddressablesService.initializeLibrary();

    _pages = <Widget>[
      const HomeScreen(),
      SequenceBuilderScreen(
        sequenceController: widget.sequenceController,
        libraryController: _libraryController,
        onBuildUnitySequence: buildAndOpenUnity,
      ),
      UnityPreviewScreen(
        unityService: widget.unityService,
        sequenceController: widget.sequenceController,
        embeddedInTab: true,
      ),
      FullLibraryScreen(libraryController: _libraryController),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _libraryController.dispose();
    _remoteAddressablesService.dispose();
    super.dispose();
  }

  Future<void> buildAndOpenUnity() async {
    await _remoteAddressablesService.ensureUnityPrepared();

    await widget.unityService.preparePreview(
      sequenceName: widget.sequenceController.sequenceName,
      animations: widget.sequenceController.getAnimationNamesForUnity(),
    );

    if (!mounted) return;

    setState(() {
      _currentIndex = 2;
    });
  }

  Future<void> _openUnityPreview() async {
    await buildAndOpenUnity();
  }

  Future<void> _onNavTapped(int index) async {
    if (_currentIndex == 2 && index != 2) {
      await widget.unityService.pauseUnity();
      _remoteAddressablesService.markUnityStateDirty();
    }

    if (index == 2) {
      await _openUnityPreview();
      if (!mounted) return;
      setState(() {
        _currentIndex = 2;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeInset = MediaQuery.of(context).padding.bottom;
    final navBottom = math.max(
      AppShell.floatingNavBottomSpacing,
      bottomSafeInset,
    );

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
          Positioned(
            left: AppShell.floatingNavHorizontalPadding,
            right: AppShell.floatingNavHorizontalPadding,
            bottom: navBottom,
            child: _FloatingNavBar(
              currentIndex: _currentIndex,
              onTap: _onNavTapped,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final Future<void> Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavButton(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                isSelected: currentIndex == 0,
                label: 'Home',
                onTap: () => onTap(0),
              ),
              _NavButton(
                icon: Icons.playlist_add_outlined,
                selectedIcon: Icons.playlist_add,
                isSelected: currentIndex == 1,
                label: 'Builder',
                onTap: () => onTap(1),
              ),
              _NavButton(
                icon: Icons.view_in_ar_outlined,
                selectedIcon: Icons.view_in_ar,
                isSelected: currentIndex == 2,
                label: 'Unity',
                onTap: () => onTap(2),
              ),
              _NavButton(
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view,
                isSelected: currentIndex == 3,
                label: 'Library',
                onTap: () => onTap(3),
              ),
              _NavButton(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                isSelected: currentIndex == 4,
                label: 'Profile',
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected ? Colors.white : Colors.white70;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: foregroundColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: foregroundColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
