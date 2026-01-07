import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for offline authentication
/// Caches credentials locally for offline login capability
class OfflineAuthService {
  static const String _credentialsKey = 'cached_credentials';
  static const String _lastLoginKey = 'last_login_timestamp';
  static const int _maxOfflineDays = 30; // Credentials valid for 30 days offline

  /// Save credentials after successful online login
  /// Stores a hash of email+password, never the raw password
  Future<void> saveCredentials(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create secure hash of credentials
      final hash = _hashCredentials(email, password);
      
      // Store hash and timestamp
      await prefs.setString(_credentialsKey, jsonEncode({
        'email': email.toLowerCase().trim(),
        'hash': hash,
      }));
      await prefs.setInt(_lastLoginKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('✅ Offline credentials cached for: $email');
    } catch (e) {
      debugPrint('⚠️ Failed to cache credentials: $e');
    }
  }

  /// Validate credentials offline
  /// Returns true if credentials match stored hash and are not expired
  Future<bool> validateOffline(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if credentials exist
      final storedJson = prefs.getString(_credentialsKey);
      if (storedJson == null) {
        debugPrint('❌ No cached credentials found');
        return false;
      }
      
      // Check if credentials are expired
      final lastLogin = prefs.getInt(_lastLoginKey) ?? 0;
      final daysSinceLogin = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastLogin))
          .inDays;
      
      if (daysSinceLogin > _maxOfflineDays) {
        debugPrint('❌ Cached credentials expired ($daysSinceLogin days old)');
        return false;
      }
      
      // Validate hash
      final stored = jsonDecode(storedJson) as Map<String, dynamic>;
      final storedEmail = stored['email'] as String;
      final storedHash = stored['hash'] as String;
      
      if (email.toLowerCase().trim() != storedEmail) {
        debugPrint('❌ Email mismatch');
        return false;
      }
      
      final inputHash = _hashCredentials(email, password);
      if (inputHash != storedHash) {
        debugPrint('❌ Password hash mismatch');
        return false;
      }
      
      debugPrint('✅ Offline authentication successful');
      return true;
    } catch (e) {
      debugPrint('⚠️ Offline validation error: $e');
      return false;
    }
  }

  /// Get the cached email if exists
  Future<String?> getCachedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString(_credentialsKey);
      if (storedJson == null) return null;
      
      final stored = jsonDecode(storedJson) as Map<String, dynamic>;
      return stored['email'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Check if valid cached credentials exist
  Future<bool> hasCachedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString(_credentialsKey);
      if (storedJson == null) return false;
      
      final lastLogin = prefs.getInt(_lastLoginKey) ?? 0;
      final daysSinceLogin = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastLogin))
          .inDays;
      
      return daysSinceLogin <= _maxOfflineDays;
    } catch (e) {
      return false;
    }
  }

  /// Clear cached credentials (on logout)
  Future<void> clearCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_credentialsKey);
      await prefs.remove(_lastLoginKey);
      debugPrint('🗑️ Cached credentials cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear credentials: $e');
    }
  }

  /// Create SHA-256 hash of email + password
  String _hashCredentials(String email, String password) {
    final input = '${email.toLowerCase().trim()}:$password';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
