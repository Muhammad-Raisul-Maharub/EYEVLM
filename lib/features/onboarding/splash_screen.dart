import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Artificial delay removed for speed
    // await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // User logged in -> Home
      context.go('/');
    } else {
      // Not logged in -> Check if seen onboarding
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final hasSeen = prefs.getBool('hasSeenOnboarding') ?? false;
      
      if (hasSeen) {
        context.go('/login');
      } else {
        context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.remove_red_eye_rounded, size: 80, color: Colors.white),
            SizedBox(height: 16),
            Text(
              "EyeVLM",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
             SizedBox(height: 16),
             CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
