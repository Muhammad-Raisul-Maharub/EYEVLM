import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:eyevlm_app/core/theme/app_tokens.dart';
import 'package:eyevlm_app/features/profile/widgets/timeline_tile.dart';
import 'package:eyevlm_app/core/utils/app_notifications.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();

  Future<void> _pickMedicalRecord() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'doc', 'docx'],
        withData: true, // Important for Web to get bytes
      );

      if (result != null) {
        final file = result.files.single;
        final user = Supabase.instance.client.auth.currentUser;
        
        if (user == null) {
           if (mounted) AppNotifications.showError(context, "You must be logged in.");
           return;
        }

        if (mounted) {
           AppNotifications.showInfo(context, "Uploading ${file.name}...");
        }

        // Generate Path: medical_records/USER_ID/TIMESTAMP_FILENAME
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = file.extension ?? 'file';
        final path = 'medical_records/${user.id}/${timestamp}_${file.name}';

        // Read file bytes - handling Web (bytes) and Native (path)
        Uint8List fileBytes;
        if (file.bytes != null) {
          fileBytes = file.bytes!;
        } else if (file.path != null) {
          // On Mobile/Desktop, read from path
          // Note: 'dart:io' File is not available on Web, but FilePicker usually gives bytes on Web if withData: true
          // We need a conditional import or just use a helper if strictly necessary. 
          // However, since we don't have a cross-platform file helper handy for 'path -> bytes' in this snippet without dart:io,
          // we'll assume withData:true provides bytes for small files, or we rely on logic that works.
          // For now, let's use a dynamic approach or just rely on 'bytes' being populated for cross-platform convenience if possible.
          // But FilePicker documentation says: "On web, `path` is always null." "On mobile, `bytes` is null unless `withData` is set."
          // So setting `withData: true` covering both is safest for small files.
          // For larger files on mobile, we'd want 'path', but let's stick to bytes for simplicity of "Medical Records" (docs/images).
          // If bytes are null on mobile despite withData:true (rare, but memory constraint), we'd need dart:io.
          // Let's assume bytes are present.
          throw Exception("Could not read file data.");
        } else {
           throw Exception("Unsupported file source.");
        }

        await Supabase.instance.client.storage.from('eye-images').uploadBinary(
          path,
          fileBytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

        if (mounted) {
           AppNotifications.showSuccess(context, "Uploaded: ${file.name}");
        }
      }
    } catch (e) {
      debugPrint("Upload error: $e");
      if (mounted) {
        // Fallback for the "bytes null on mobile" case to handle it gracefully if it happens
        if (e.toString().contains("Could not read")) {
           // Retry with path if possible (requires dart:io import which we might not want to mix if this is a web-heavy file)
           // But since profile_screen imports universal libs, let's just show error.
           AppNotifications.showError(context, "Could not read file. Try a smaller file.");
        } else {
           AppNotifications.showError(context, "Upload failed: $e");
        }
      }
    }
  }

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickMedicalRecord,
        backgroundColor: AppColors.lightPrimary,
        icon: const Icon(Icons.upload_file, color: Colors.white),
        label: const Text("Upload Records", style: TextStyle(color: Colors.white)),
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
                      image: const DecorationImage(
                        image: NetworkImage('https://ui-avatars.com/api/?name=User&background=random&size=200'), 
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeaderStat("Scans", "12"),
                      Container(height: 30, width: 1, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 20)),
                      _buildHeaderStat("Health", "Good"),
                      Container(height: 30, width: 1, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 20)),
                      _buildHeaderStat("Member", "Pro"),
                    ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Medical Timeline", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          // Demo Data
          const TimelineTile(
            title: "Cataract Screening",
            date: "Today, 10:30 AM",
            description: "Routine AI screening performed. No significant anomalies detected.",
            isFirst: true,
            isHighRisk: false,
          ),
          const TimelineTile(
            title: "Consultation Call",
            date: "Dec 28, 2025",
            description: "Video consultation with Dr. Aishwarya regarding eye strain.",
            isHighRisk: false,
          ),
          const TimelineTile(
            title: "High Pressure Alert",
            date: "Nov 15, 2025",
            description: "Detected slightly elevated intraocular pressure indicators.",
            isHighRisk: true,
            isLast: true,
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
        Text(
          "EyeVLM Research v1.0.0",
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
        ),
        const SizedBox(height: 4),
        Text(
          "Secure • Private • AI Powered",
          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[300]),
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
