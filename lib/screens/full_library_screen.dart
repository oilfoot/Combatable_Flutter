import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../widgets/animation_info_sheet.dart';
import '../widgets/animation_library_card.dart';

class FullLibraryScreen extends StatefulWidget {
  const FullLibraryScreen({super.key, required this.libraryController});

  final LibraryController libraryController;

  @override
  State<FullLibraryScreen> createState() => _FullLibraryScreenState();
}

class _FullLibraryScreenState extends State<FullLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _showInstalledOnly = false;
  bool _showRecommendedOnly = false;

  @override
  void initState() {
    super.initState();
    widget.libraryController.addListener(_onLibraryChanged);
  }

  @override
  void dispose() {
    widget.libraryController.removeListener(_onLibraryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showAnimationInfo(LibraryDisplayItem entry) async {
    await AnimationInfoSheet.show(
      context,
      item: entry.item,
      isDownloaded: entry.isInstalled,
      isDownloading: entry.isDownloading,
      buttonText: widget.libraryController.getPrimaryActionLabel(entry),
      onPrimaryAction: () async {
        try {
          await widget.libraryController.performPrimaryAction(entry);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add ${entry.item.title}: $e')),
          );
        }
      },
    );
  }

  Future<void> _handlePrimaryAction(LibraryDisplayItem entry) async {
    try {
      await widget.libraryController.performPrimaryAction(entry);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add ${entry.item.title}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.libraryController;
    final remote = library.remoteAddressablesService;

    var items = _showRecommendedOnly
        ? library.recommendedNextItems
        : library.allItems;

    items = items.where((entry) {
      if (_showInstalledOnly && !entry.isInstalled) return false;
      return library.matchesSearch(entry, _searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Full Library')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search animations...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Installed'),
                        selected: _showInstalledOnly,
                        onSelected: (value) {
                          setState(() {
                            _showInstalledOnly = value;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Recommended Next'),
                        selected: _showRecommendedOnly,
                        onSelected: (value) {
                          setState(() {
                            _showRecommendedOnly = value;
                          });
                        },
                      ),
                      ActionChip(
                        label: Text(
                          remote.isInitializing
                              ? 'Refreshing...'
                              : 'Refresh Library',
                        ),
                        onPressed: remote.isInitializing
                            ? null
                            : () async {
                                await library.refreshLibrary();
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('No animations match your filters'),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.92,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final entry = items[index];

                        return AnimationLibraryCard(
                          width: double.infinity,
                          item: entry.item,
                          isDownloaded: entry.isInstalled,
                          isDownloading: entry.isDownloading,
                          showStatus: entry.isRemote,
                          buttonText: library.getPrimaryActionLabel(entry),
                          onTap: () => _showAnimationInfo(entry),
                          onPrimaryAction: () => _handlePrimaryAction(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
