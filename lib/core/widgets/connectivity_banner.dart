import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/connectivity_provider.dart';

/// A banner that shows at the top of the screen when offline
/// Automatically appears/disappears based on connectivity state
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityProvider);
    
    return connectivityAsync.when(
      data: (isOnline) {
        if (isOnline) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You are offline. Some features may be limited.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -1, end: 0);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// A small indicator icon for connectivity status
/// Can be used in app bars or other compact spaces
class ConnectivityIndicator extends ConsumerWidget {
  final double size;
  final bool showOnlineState;

  const ConnectivityIndicator({
    super.key,
    this.size = 24,
    this.showOnlineState = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    
    if (isOnline && !showOnlineState) {
      return const SizedBox.shrink();
    }
    
    return Tooltip(
      message: isOnline ? 'Online' : 'Offline',
      child: Icon(
        isOnline ? Icons.wifi : Icons.wifi_off_rounded,
        size: size,
        color: isOnline ? Colors.green : Colors.orange,
      ),
    );
  }
}

/// Wrapper widget that shows connectivity banner above its child
class ConnectivityAwareScaffold extends ConsumerWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  const ConnectivityAwareScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }
}
