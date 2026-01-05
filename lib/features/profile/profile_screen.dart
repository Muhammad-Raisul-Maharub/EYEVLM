import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:eyevlm_app/features/profile/widgets/timeline_tile.dart';
import 'package:eyevlm_app/core/utils/app_notifications.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();


  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? "Guest User";
    // Extract name if available or use a placeholder
    final name = user?.userMetadata?['full_name'] ?? "EyeVLM Member";

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background handled by BaseScaffold, but successful Glassmorphism needs something behind it.
          // Since we are likely inside BaseScaffold, we assume a background exists.
          
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 0), // Important for overlap
            child: Column(
              children: [
                _buildGlassHeader(name, email),
                const SizedBox(height: 24),
                _buildMedicalHistory(),
                const SizedBox(height: 24),
                _buildSettingsSection(context),
                const SizedBox(height: 40),
                _buildFooter(),
                const SizedBox(height: 100), // Spacing for FAB/Bottom interactions
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassHeader(String name, String email) {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // 1. Frost Effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.teal.shade900.withAlpha(100), // Dark overlay
              ),
            ),
          ),
          
          // 2. Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 20),
                      ],
                      image: DecorationImage(
                        image: NetworkImage('https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&size=200'), 
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    email,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  // Stats Row
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client.from('scans').stream(primaryKey: ['id']).eq('user_id', Supabase.instance.client.auth.currentUser!.id),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildHeaderStat("Scans", "$count"),
                          Container(height: 30, width: 1, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 20)),
                          _buildHeaderStat("Health", "Tracked"),
                          Container(height: 30, width: 1, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 20)),
                          _buildHeaderStat("Member", "Free"),
                        ],
                      );
                    }
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildMedicalHistory() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Recent Activity", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('scans').stream(primaryKey: ['id']).eq('user_id', userId).order('created_at', ascending: false).limit(2),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text("No recent scans found.", style: TextStyle(color: Colors.grey));
              }
              final scans = snapshot.data!;
              return Column(
                children: scans.map((scan) {
                   final date = DateTime.parse(scan['created_at']);
                   final prediction = scan['prediction'] ?? 'Processing';
                   return TimelineTile(
                     title: prediction,
                     date: DateFormat('MMM d, h:mm a').format(date),
                     description: scan['suspected_disease'] ?? 'Routine Scan',
                     isHighRisk: prediction != 'Healthy' && prediction != 'Pending',
                     isFirst: scans.first == scan,
                     isLast: scans.last == scan,
                   );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text("Settings", style: Theme.of(context).textTheme.titleLarge),
           const SizedBox(height: 10),
           _ProfileTile(
             icon: Icons.settings, 
             title: "General Settings", 
             onTap: () => context.push('/profile/settings'),
           ),
           _ProfileTile(
             icon: Icons.notifications, 
             title: "Notification Preferences", 
             onTap: () => _showComingSoon(context, "Notifications"),
           ),
           _ProfileTile(
             icon: Icons.security, 
             title: "Privacy & Security", 
             onTap: () => context.push('/profile/privacy'),
           ),
           _ProfileTile(
             icon: Icons.logout,
             title: "Log Out",
             onTap: () async {
               await Supabase.instance.client.auth.signOut();
               if (context.mounted) context.go('/login');
             },
             isDestructive: true,
           ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // Designed & Developed by
        Text(
          "Designed & Developed by",
          style: GoogleFonts.inter(
            fontSize: 12, 
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        
        // Raisul Maharub
        Text(
          "Raisul Maharub",
          style: GoogleFonts.inter(
            fontSize: 14, 
            fontWeight: FontWeight.bold, 
            color: Colors.grey[700],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),

        // Version 1.0.0
        Text(
          "Version 1.0.0",
          style: GoogleFonts.inter(
            fontSize: 12, 
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    AppNotifications.showInfo(context, "$feature coming soon!");
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileTile({required this.icon, required this.title, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
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
            color: isDestructive ? Colors.red.withAlpha(25) : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: isDestructive ? Colors.red : Colors.grey[700], size: 20),
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: isDestructive ? Colors.red : null)),
        trailing: Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
      ),
    );
  }
}
