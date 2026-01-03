import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? "Guest User";

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🟦 1. HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                children: [
                   CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFFE0F2F1),
                    child: const Icon(Icons.person, size: 40, color: Color(0xFF009688)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "My Profile",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    email,
                    style: GoogleFonts.inter(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ⚙️ 2. SETTINGS LIST
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _ProfileTile(
                    icon: Icons.settings, 
                    title: "Settings", 
                    onTap: () => context.push('/profile/settings'),
                  ),
                  _ProfileTile(
                    icon: Icons.notifications, 
                    title: "Notifications", 
                    onTap: () => _showComingSoon(context, "Notifications"),
                  ),
                  _ProfileTile(
                    icon: Icons.security, 
                    title: "Privacy & Security", 
                    onTap: () => context.push('/profile/privacy'),
                  ),
                  _ProfileTile(
                    icon: Icons.help_outline, 
                    title: "Help & Support", 
                    onTap: () => context.push('/profile/help'),
                  ),
                   _ProfileTile(
                    icon: Icons.balance, 
                    title: "Ethical AI & Data", 
                    onTap: () => context.push('/profile/ethics'),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 🚪 LOGOUT BUTTON
                  ListTile(
                    onTap: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) context.go('/login');
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout, color: Colors.red),
                    ),
                    title: Text(
                      "Log Out",
                      style: GoogleFonts.poppins(
                        color: Colors.red, 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 👨‍💻 3. DEVELOPER CREDIT (The Professional Spot)
            Column(
              children: [
                Text(
                  "Version 1.0.0",
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[400]),
                ),
                const SizedBox(height: 4),
                Text(
                  "Designed & Developed by",
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
                ),
                Text(
                  "Raisul Maharub",
                  style: GoogleFonts.poppins(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.grey[600]
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$feature coming soon!"), duration: const Duration(seconds: 1)),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(13),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey[700], size: 20),
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
      ),
    );
  }
}
