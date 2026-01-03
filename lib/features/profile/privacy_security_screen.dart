import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Privacy & Security",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: "1. Data Collection"),
            _SectionContent(
              content: "EyeVLM collects strictly necessary data to provide early disease detection services. This includes:\\n"
                  "• Detailed eye images uploaded by you.\\n"
                  "• Symptom descriptions provided during submission.\\n"
                  "• Account information (email) for identification.",
            ),
            
            _SectionHeader(title: "2. Data Usage"),
            _SectionContent(
              content: "Your data is used solely for:\\n"
                  "• Generating medical inference and health reports.\\n"
                  "• Improving the accuracy of our AI models (only with your consent).\\n"
                  "• We do NOT sell or share your personal data with third-party advertisers.",
            ),

            _SectionHeader(title: "3. Data Storage & Security"),
            _SectionContent(
              content: "• All data is encrypted in transit and at rest using industry-standard protocols.\\n"
                  "• Images are stored securely in Supabase Storage with strict Row Level Security (RLS) policies.\\n"
                  "• Only you have access to your submission history.",
            ),

            _SectionHeader(title: "4. User Rights"),
            _SectionContent(
              content: "You retain full ownership of your data. You have the right to:\\n"
                  "• Access your complete scan history.\\n"
                  "• Delete specific scans or your entire account at any time.\\n"
                  "• Request a copy of your stored data.",
            ),

            const SizedBox(height: 24),
            Center(
              child: Text(
                "Last Updated: January 2026",
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 12.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF009688),
        ),
      ),
    );
  }
}

class _SectionContent extends StatelessWidget {
  final String content;
  const _SectionContent({required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        content,
        style: GoogleFonts.inter(
          fontSize: 14,
          height: 1.6,
          color: Colors.grey[800],
        ),
      ),
    );
  }
}
