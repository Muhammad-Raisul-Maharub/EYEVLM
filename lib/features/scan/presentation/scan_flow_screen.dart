import 'package:flutter/material.dart';
import 'package:eyevlm_app/features/scan/presentation/smart_camera_screen.dart';
import 'package:eyevlm_app/features/scan/presentation/clinical_data_form.dart';
import 'package:eyevlm_app/features/scan/data/scan_repository.dart';

/// A complete scan flow widget that automatically links:
/// Smart Camera → Clinical Form → Database Upload
/// 
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (context) => const ScanFlowScreen()),
/// );
/// ```
class ScanFlowScreen extends StatelessWidget {
  const ScanFlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SmartCameraScreen(
      onImageCaptured: (String imagePath) {
        // Auto-navigate to Clinical Form after capture
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClinicalDataForm(
              imagePath: imagePath,
              onSubmit: (formData) async {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  // Call the Auto-Pilot service
                  await ScanRepository().submitScan(
                    imagePath: imagePath,
                    formData: formData,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close loading dialog
                    
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Scan uploaded successfully!"),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Navigate back to home
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close loading dialog
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }
}
