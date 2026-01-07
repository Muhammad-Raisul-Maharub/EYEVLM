import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Global connectivity state provider
/// Tracks online/offline status across the entire app
class ConnectivityNotifier extends AsyncNotifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  Future<bool> build() async {
    // Initial connectivity check
    final result = await Connectivity().checkConnectivity();
    final isOnline = _isConnected(result);
    
    // Start listening for changes
    _startListening();
    
    ref.onDispose(() {
      _subscription?.cancel();
    });
    
    return isOnline;
  }

  void _startListening() {
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = _isConnected(result);
      state = AsyncValue.data(isOnline);
      debugPrint('📶 Connectivity changed: ${isOnline ? "ONLINE" : "OFFLINE"}');
    });
  }

  bool _isConnected(List<ConnectivityResult> result) {
    return result.isNotEmpty && 
           !result.contains(ConnectivityResult.none);
  }

  /// Force a connectivity check
  Future<bool> checkNow() async {
    final result = await Connectivity().checkConnectivity();
    final isOnline = _isConnected(result);
    state = AsyncValue.data(isOnline);
    return isOnline;
  }
}

/// Provider for connectivity state
final connectivityProvider = AsyncNotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);

/// Simple synchronous provider for quick checks
/// Returns false if connectivity state is unknown
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.value ?? true; // Default to online if unknown
});
