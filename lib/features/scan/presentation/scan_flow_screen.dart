import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:eyevlm_app/features/scan/presentation/smart_camera_screen.dart';
import 'package:eyevlm_app/features/scan/presentation/clinical_data_form.dart';
import 'package:eyevlm_app/features/scan/data/scan_repository.dart';
import 'package:eyevlm_app/core/theme/app_tokens.dart';

/// A complete scan flow widget that automatically links:
/// Smart Camera -> Image Cropper -> Clinical Form -> Database Upload
class ScanFlowScreen extends StatelessWidget {
  const ScanFlowScreen({super.key});

  Future<void> _handleImageCaptured(BuildContext context, String rawImagePath) async {
    // 1. Crop the Image
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: rawImagePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square Crop
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Eye Image',
          toolbarColor: AppColors.lightPrimary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true, // Force Square
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Crop Eye Image',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile != null && context.mounted) {
      // 2. Navigate to Clinical Form with CROPPED image
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ClinicalDataForm(
            imagePath: croppedFile.path,
            onSubmit: (formData) => _submitData(context, croppedFile.path, formData),
          ),
        ),
      );
    }
  }

  Future<void> _submitData(BuildContext context, String imagePath, Map<String, dynamic> formData) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.lightPrimary),
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
  }

  @override
  Widget build(BuildContext context) {
    return SmartCameraScreen(
      onImageCaptured: (path) => _handleImageCaptured(context, path),
    );
  }
}
