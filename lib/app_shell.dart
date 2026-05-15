import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'controllers/library_controller.dart';
import 'controllers/sequence_controller.dart';
import 'screens/full_library_screen.dart';
import 'widgets/floating_nav_bar.dart';
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

  /// Use this inside scrollable screens for bottom spacing.
  static const double floatingNavExtraScrollSpace = 130;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 1;
  bool _isNavExpanded = false;

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

    _pages = [
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

  void _expandNav() {
    if (_isNavExpanded) return;
    setState(() {
      _isNavExpanded = true;
    });
  }

  void _collapseNav() {
    if (!_isNavExpanded) return;
    setState(() {
      _isNavExpanded = false;
    });
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
    _expandNav();

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
      _isNavExpanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeInset = MediaQuery.of(context).padding.bottom;

    final expandedBottom = math.max(
      AppShell.floatingNavBottomSpacing,
      bottomSafeInset,
    );

    final collapsedBottom = math.max(4.0, expandedBottom - 10);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _collapseNav(),
              onPointerMove: (_) => _collapseNav(),
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: AppShell.floatingNavHorizontalPadding,
            right: AppShell.floatingNavHorizontalPadding,
            bottom: _isNavExpanded ? expandedBottom : collapsedBottom,
            child: FloatingNavBar(
              currentIndex: _currentIndex,
              isExpanded: _isNavExpanded,
              onNavPressed: _expandNav,
              onTap: _onNavTapped,
            ),
          ),
        ],
      ),
    );
  }
}
