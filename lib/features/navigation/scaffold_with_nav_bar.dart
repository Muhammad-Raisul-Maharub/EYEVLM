import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_strings.dart';

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  /// The navigation shell and container for the branch Navigators.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: [
          NavigationDestination(label: AppStrings.tr(ref, 'navHome'), icon: const Icon(Icons.home)),
          NavigationDestination(label: AppStrings.tr(ref, 'navHistory'), icon: const Icon(Icons.history)),
          NavigationDestination(label: AppStrings.tr(ref, 'navProfile'), icon: const Icon(Icons.person)),
        ],
        onDestinationSelected: (index) => _onTap(context, index),
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      // A common pattern when switching branches, for example in iOS apps, is to
      // support clicking the selected item to scroll to top.
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
