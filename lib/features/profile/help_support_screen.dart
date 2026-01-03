import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Frequently Asked Questions",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFaqItem(
            "How do I use the app?",
            "Tap the 'Analyze Eye' button on the home screen, take a picture of your eye, and wait for the AI analysis.",
          ),
          _buildFaqItem(
            "Is the diagnosis accurate?",
            "This app provides an early indication only. It is NOT a medical diagnosis. Always consult a doctor.",
          ),
          _buildFaqItem(
            "Is my data safe?",
            "Yes, your images are stored securely and used only for analysis.",
          ),
          const SizedBox(height: 32),
          const Text(
            "Contact Us",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.email),
            title: Text("Email Support"),
            subtitle: Text("raisulmaharub5@gmail.com"),
          ),
          const ListTile(
            leading: Icon(Icons.phone),
            title: Text("Helpline"),
            subtitle: Text("01632724055"),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(answer),
        ),
      ],
    );
  }
}
