import 'package:flutter/material.dart';

class EthicalReasoningScreen extends StatelessWidget {
  const EthicalReasoningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ethical AI & Data")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              "AI Disclaimer",
              "The EyeVLM system uses advanced machine learning to analyze eye images. However, AI models can make mistakes. This tool is designed to provide 'Early Indications' to assist users in deciding whether to seek professional help. It is NOT a substitute for professional medical advice, diagnosis, or treatment.",
            ),
             _buildSection(
              "Data Privacy & Usage",
              "We value your privacy. Your eye images are uploaded to a secure database for the sole purpose of analysis. We do not sell your personal data to third parties. We may use anonymized data to improve our model's accuracy over time.",
            ),
             _buildSection(
              "Bias & Fairness",
              "We strive to train our AI on diverse datasets to ensure fair performance across different demographics. However, as with all AI systems, biases may exist. We are continuously working to improve fairness.",
            ),
             _buildSection(
              "Transparency",
              "We believe in transparency. The app provides a 'Confidence Score' with every result to help you understand the model's certainty. Always consider the explanation provided.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}
