import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/pdf_service.dart';

class ScanResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;

  const ScanResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    // Parse Data
    final prediction = result['predicted_class'] as String? ?? 'Unknown';
    // Handle both 'confidence' as Map (from backend) or double (if we passed the parsed one, relying on backend specific response structure)
    // The backend response has 'confidence' as a Map<String, float>.
    // But submission_service might return the wrapper.
    // Let's assume result is the direct JSON from backend: {predicted_class: "...", confidence: {...}}
    
    double confidenceValue = 0.0;
    if (result['confidence'] is Map) {
      final confMap = result['confidence'] as Map<String, dynamic>;
      confidenceValue = (confMap[prediction] ?? 0.0).toDouble();
    } else if (result['confidence'] is num) {
        confidenceValue = (result['confidence'] as num).toDouble();
    }

    final String confidencePercent = "${(confidenceValue * 100).toStringAsFixed(1)}%";
    // We assume result['image_url'] was passed through or we have it. 
    // Wait, the backend response might NOT contain 'image_url' if it just returns inference! 
    // submission_service.submitInference returns jsonDecode(response.body).
    // The backend `infer` endpoint returns {predicted_class, confidence}. It does NOT echo image_url.
    // We MUST pass image_url to this screen separately or inject it into the result map in submission_service.
    
    final String? imageUrl = result['saved_image_url'] ?? result['image_url']; // We will need to ensure this is passed
    final String symptoms = result['symptoms'] ?? 'None';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Analysis Result"),
        centerTitle: true,
        automaticallyImplyLeading: false, // Don't allow back to submission form easily to prevent duplicate
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. Hero Animation
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 80, color: Colors.teal)
                  .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            ),
            const SizedBox(height: 24),
            
            Text(
              "Analysis Complete",
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Based on the AI analysis of your scan:",
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
            
            const SizedBox(height: 30),
            
            // 2. Result Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.withAlpha(51)),
                boxShadow: [
                  BoxShadow(color: Colors.teal.withAlpha(26), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                   Text(
                    prediction.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Confidence: $confidencePercent",
                    style: GoogleFonts.inter(
                      fontSize: 14, 
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ).animate().slideY(begin: 0.3, duration: 500.ms, delay: 200.ms).fadeIn(),

            const SizedBox(height: 40),
            
            // 3. Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go('/'); 
                    },
                    icon: const Icon(Icons.home),
                    label: const Text("Home"),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (imageUrl != null) {
                         PdfService().generateAndShareReport(
                           imageUrl: imageUrl, 
                           prediction: prediction, 
                           confidence: confidencePercent, 
                           symptoms: symptoms, 
                           date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                         );
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Image URL missing, cannot generate PDF")));
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text("Download PDF"),
                     style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            Text(
              "A record of this scan has been saved to your History.",
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
