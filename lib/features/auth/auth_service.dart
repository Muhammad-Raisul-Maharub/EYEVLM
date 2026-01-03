import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

class AuthService {
  final GoTrueClient _auth = Supabase.instance.client.auth;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await _auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
  
  bool get isAdmin {
    // Check metadata or profile table for admin role
    // For now, we will assume a specific email for admin or metadata
    // if implemented in `profiles` table.
    final metadata = currentUser?.appMetadata;
    return metadata?['role'] == 'admin' || metadata?['role'] == 'service_role';
  }
}
