import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// A widget that shows the current network connectivity status
/// Displays a green ONLINE or red OFFLINE indicator bar
class ConnectivityStatusWidget extends StatefulWidget {
  final Widget child;
  
  const ConnectivityStatusWidget({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityStatusWidget> createState() => _ConnectivityStatusWidgetState();
}

class _ConnectivityStatusWidgetState extends State<ConnectivityStatusWidget> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOnline = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((result) => result != ConnectivityResult.none);
    
    if (mounted) {
      setState(() {
        // Show banner when coming back online or going offline
        if (wasOnline != _isOnline) {
          _showBanner = true;
          // Auto-hide the banner after 3 seconds when online
          if (_isOnline) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && _isOnline) {
                setState(() => _showBanner = false);
              }
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Connectivity banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: (_showBanner || !_isOnline) ? null : 0,
          child: _buildStatusBanner(),
        ),
        // Main content
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _isOnline ? Colors.green : Colors.red.shade700,
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isOnline ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _isOnline ? "Back Online" : "OFFLINE MODE - Data will sync when connected",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (!_isOnline) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact connectivity indicator for use in app bars or status areas
class ConnectivityDot extends StatefulWidget {
  final double size;
  
  const ConnectivityDot({super.key, this.size = 10});

  @override
  State<ConnectivityDot> createState() => _ConnectivityDotState();
}

class _ConnectivityDotState extends State<ConnectivityDot> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (mounted) {
      setState(() {
        _isOnline = results.any((result) => result != ConnectivityResult.none);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _isOnline ? "Online" : "Offline",
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isOnline ? Colors.green : Colors.red,
          boxShadow: [
            BoxShadow(
              color: (_isOnline ? Colors.green : Colors.red).withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
