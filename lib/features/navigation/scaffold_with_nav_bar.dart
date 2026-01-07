import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers/connectivity_provider.dart';
import '../auth/auth_service.dart';

/// Scaffold with bottom navigation bar
/// Conditionally shows Admin tab for admin users
class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  /// The navigation shell and container for the branch Navigators.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final isAdmin = authService.isAdmin;
    final isOnline = ref.watch(isOnlineProvider);
    
    // Build destinations dynamically based on user role
    List<NavigationDestination> destinations = [
      NavigationDestination(
        label: AppStrings.tr(ref, 'navHome'),
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
      ),
      NavigationDestination(
        label: AppStrings.tr(ref, 'navHistory'),
        icon: const Icon(Icons.history_outlined),
        selectedIcon: const Icon(Icons.history),
      ),
      if (isAdmin)
        const NavigationDestination(
          label: 'Admin',
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
        ),
      NavigationDestination(
        label: AppStrings.tr(ref, 'navProfile'),
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
      ),
    ];

    return Scaffold(
      body: Column(
        children: [
          // Offline banner
          if (!isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.shade700,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You are offline',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getSelectedIndex(isAdmin, navigationShell.currentIndex),
        destinations: destinations,
        onDestinationSelected: (index) => _onTap(context, index, isAdmin),
      ),
    );
  }

  /// Get the correct selected index accounting for admin tab presence
  int _getSelectedIndex(bool isAdmin, int currentIndex) {
    if (!isAdmin) {
      // Non-admin: 0=Home, 1=History, 2=Profile
      // Branch indexes: 0=Home, 1=History, 2=Admin(hidden), 3=Profile
      if (currentIndex == 3) return 2; // Profile
      return currentIndex;
    }
    // Admin: 0=Home, 1=History, 2=Admin, 3=Profile
    return currentIndex;
  }

  void _onTap(BuildContext context, int index, bool isAdmin) {
    int branchIndex = index;
    
    if (!isAdmin) {
      // Non-admin: Map UI index to branch index
      // UI: 0=Home, 1=History, 2=Profile
      // Branch: 0=Home, 1=History, 2=Admin, 3=Profile
      if (index == 2) branchIndex = 3; // Profile is at branch 3
    }
    
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }
}
