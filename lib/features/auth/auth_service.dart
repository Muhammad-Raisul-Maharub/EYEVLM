import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/offline_auth_service.dart';
import '../../core/providers/connectivity_provider.dart';

final authServiceProvider = Provider((ref) => AuthService(ref));

final offlineAuthServiceProvider = Provider((ref) => OfflineAuthService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// User role enum
enum UserRole { user, admin }

class AuthService {
  final Ref _ref;
  final GoTrueClient _auth = Supabase.instance.client.auth;
  
  // Admin email constant
  static const String adminEmail = 'admin@eyevlm.com';

  AuthService(this._ref);

  /// Sign in - checks connectivity and uses appropriate method
  Future<void> signIn(String email, String password) async {
    final isOnline = _ref.read(isOnlineProvider);
    
    if (isOnline) {
      // Online: Use Supabase auth
      await _auth.signInWithPassword(email: email, password: password);
      
      // Cache credentials for offline use
      await _ref.read(offlineAuthServiceProvider).saveCredentials(email, password);
      
      debugPrint('✅ Online login successful, credentials cached');
    } else {
      // Offline: Validate against cached credentials
      final offlineAuth = _ref.read(offlineAuthServiceProvider);
      final isValid = await offlineAuth.validateOffline(email, password);
      
      if (!isValid) {
        throw Exception('Offline login failed. Please connect to the internet or check your credentials.');
      }
      
      debugPrint('✅ Offline login successful');
    }
  }

  /// Sign up - requires online connection
  Future<void> signUp(String email, String password) async {
    final isOnline = _ref.read(isOnlineProvider);
    
    if (!isOnline) {
      throw Exception('Sign up requires an internet connection. Please connect and try again.');
    }
    
    await _auth.signUp(email: email, password: password);
  }

  /// Sign out - clears both Supabase session and cached credentials
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('⚠️ Supabase sign out error (may be offline): $e');
    }
    
    // Always clear cached credentials on logout
    await _ref.read(offlineAuthServiceProvider).clearCredentials();
  }

  /// Get current user (may be null if offline and not logged in via Supabase)
  User? get currentUser => _auth.currentUser;
  
  /// Check if user is logged in (online or offline)
  Future<bool> isLoggedIn() async {
    // Check Supabase session first
    if (_auth.currentUser != null) return true;
    
    // Check for valid cached credentials (for offline mode)
    final hasCached = await _ref.read(offlineAuthServiceProvider).hasCachedCredentials();
    return hasCached;
  }

  /// Get cached email for offline mode
  Future<String?> getCachedEmail() async {
    return await _ref.read(offlineAuthServiceProvider).getCachedEmail();
  }

  /// Check if current user is admin
  bool get isAdmin {
    final user = currentUser;
    if (user == null) return false;
    
    // Check email match
    if (user.email?.toLowerCase() == adminEmail.toLowerCase()) {
      return true;
    }
    
    // Also check app metadata for role
    final metadata = user.appMetadata;
    return metadata['role'] == 'admin' || metadata['role'] == 'service_role';
  }

  /// Get user role
  UserRole get userRole => isAdmin ? UserRole.admin : UserRole.user;
  
  /// Get display name for current user
  String get displayName {
    final user = currentUser;
    if (user == null) return 'Guest';
    
    // Try to get name from metadata
    final metadata = user.userMetadata;
    if (metadata['name'] != null) return metadata['name'];
    if (metadata['full_name'] != null) return metadata['full_name'];
    
    // Fall back to email
    return user.email?.split('@').first ?? 'User';
  }
}
