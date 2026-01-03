import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkDataConsent();
  }

  Future<void> _checkDataConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final hasConsented = prefs.getBool('hasConsentedData') ?? false;

    if (!hasConsented && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Data Usage Permission"),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("To provide you with eye disease analysis, this app needs to process your eye images."),
                SizedBox(height: 10),
                Text("• Images are uploaded to a secure server."),
                Text("• Data is used solely for analysis and service improvement."),
                Text("• Your privacy is a priority."),
                SizedBox(height: 10),
                Text("Do you consent to the processing of your data for these purposes?"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); 
              },
              child: const Text("Disagree"),
            ),
            ElevatedButton(
              onPressed: () async {
                await prefs.setBool('hasConsentedData', true);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text("I Consent"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _downloadApk() async {
    final Uri url = Uri.parse('https://drive.google.com/file/d/1hwTOH1jhE8sWYBv5xYmM31JhQx5eoaYQ/view?usp=sharing');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    // Extract name from metadata if available, otherwise use email name part
    final email = user?.email ?? 'User';
    final name = user?.userMetadata?['full_name'] ?? email.split('@').first.replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFE0F2F1),
              child: Icon(Icons.person, color: Color(0xFF009688)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Welcome Back,", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
              ],
            ),
          ],
        ),
        actions: [
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.android, color: Color(0xFF3DDC84)),
              tooltip: 'Download Android App',
              onPressed: _downloadApk,
            ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.grey),
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("No new notifications")),
               );
            }, 
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🚀 1. HERO ACTION CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF009688), Color(0xFF4DB6AC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF009688).withAlpha(77),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Start Eye Screening",
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Use AI to detect potential early signs of cataract.",
                              style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/scan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF009688),
                              ),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text("Scan Now"),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.qr_code_scanner, color: Colors.white24, size: 80),
                    ],
                  ),
                ).animate().slideX(),

                const SizedBox(height: 30),

                // 📊 2. HEALTH TIPS (Interactive)
                Text("Eye Health Tips", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      _TipCard(
                        icon: Icons.wb_sunny, 
                        title: "Wear Sunglasses", 
                        color: Colors.orange,
                        desc: "Protect your eyes from harmful UV rays which can accelerate cataract formation. Look for 100% UVA/UVB protection.",
                      ),
                      _TipCard(
                        icon: Icons.water_drop, 
                        title: "Stay Hydrated", 
                        color: Colors.blue,
                        desc: "Proper hydration is essential for tear production and keeping eyes moist. Drink at least 8 glasses of water daily.",
                      ),
                      _TipCard(
                        icon: Icons.access_time, 
                        title: "20-20-20 Rule", 
                        color: Colors.purple,
                        desc: "Every 20 minutes, look at something 20 feet away for at least 20 seconds to reduce digital eye strain.",
                      ),
                      _TipCard(
                        icon: Icons.restaurant, 
                        title: "Eat Healthy", 
                        color: Colors.green,
                        desc: "A diet rich in leafy greens (spinach, kale), fish, and nuts provides antioxidants essential for long-term vision health.",
                      ),
                      _TipCard(
                        icon: Icons.clean_hands, 
                        title: "Be Hygienic", 
                        color: Colors.teal,
                        desc: "Always wash your hands thoroughly before touching your eyes or handling contact lenses to prevent infections.",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final MaterialColor color;
  
  const _TipCard({
    required this.icon, 
    required this.title, 
    required this.color,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: color[50], // Background color
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                icon: CircleAvatar(
                  radius: 30,
                  backgroundColor: color[100],
                  child: Icon(icon, color: color, size: 36),
                ),
                title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                content: Text(desc, style: GoogleFonts.inter(), textAlign: TextAlign.center),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("Got it"),
                  ),
                ],
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 8),
                Text(
                  title, 
                  textAlign: TextAlign.center, 
                  style: TextStyle(
                    color: color[900], 
                    fontSize: 12, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.touch_app, size: 14, color: color.withAlpha(128)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
