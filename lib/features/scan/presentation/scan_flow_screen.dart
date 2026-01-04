import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:eyevlm_app/features/scan/presentation/smart_camera_screen.dart';
import 'package:eyevlm_app/features/scan/presentation/clinical_data_form.dart';
import 'package:eyevlm_app/features/scan/data/scan_repository.dart';
import 'package:eyevlm_app/core/theme/app_tokens.dart';
import 'package:eyevlm_app/core/utils/app_notifications.dart';
import 'package:file_picker/file_picker.dart';
import 'package:eyevlm_app/core/services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// A complete scan flow widget that automatically links:
/// Smart Camera -> Image Cropper -> Clinical Form -> Database Upload
class ScanFlowScreen extends StatelessWidget {
  const ScanFlowScreen({super.key});

  Future<void> _handleImageCaptured(BuildContext context, String rawImagePath) async {
    // 1. Crop the Image
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: rawImagePath,
      // aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // REMOVED: Allow free crop
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Eye Image',
          toolbarColor: AppColors.lightPrimary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false, 
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Eye Image',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
        WebUiSettings(
          context: context,
        ),
      ],
    );

    if (croppedFile != null && context.mounted) {
      // Read bytes for Web support
      final bytes = await croppedFile.readAsBytes();

      if (!context.mounted) return;

      // 2. Navigate to Clinical Form with CROPPED image
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ClinicalDataForm(
            imagePath: croppedFile.path,
            imageBytes: bytes,
            onSubmit: (formData, files) => _submitData(context, croppedFile.path, formData, files, bytes),
          ),
        ),
      );
    }
  }

  Future<void> _submitData(BuildContext context, String imagePath, Map<String, dynamic> formData, List<PlatformFile>? attachments, Uint8List? imageBytes) async {
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
        attachments: attachments,
        imageBytes: imageBytes,
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show success message
        AppNotifications.showSuccess(context, "Scan uploaded successfully!");

        // Navigate back to home
        // Show success dialog with PDF option
        _showSuccessDialog(context, formData, imagePath, attachments, imageBytes);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        AppNotifications.showError(context, "Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Scan")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOptionCard(
              context,
              icon: Icons.camera_alt,
              title: "Scan with Camera",
              subtitle: "Use AI Smart Camera",
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SmartCameraScreen(
                    onImageCaptured: (path) => _handleImageCaptured(context, path),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionCard(
              context,
              icon: Icons.upload_file,
              title: "Upload from Gallery",
              subtitle: "Pick an existing photo",
              color: Colors.orange,
              onTap: () => _pickAndCropImage(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withAlpha(51), blurRadius: 10, offset: const Offset(0, 5)),
          ],
          border: Border.all(color: color.withAlpha(128)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCropImage(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (!context.mounted) return;

      if (image != null) {
        await _handleImageCaptured(context, image.path);
      }
    } catch (e) {
      if (context.mounted) AppNotifications.showError(context, "Error picking image: $e");
    }
  }

  void _showSuccessDialog(BuildContext context, Map<String, dynamic> formData, String imagePath, List<PlatformFile>? attachments, Uint8List? imageBytes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text("Scan Submitted!")]),
        content: const Text("Your data has been securely uploaded.\nThe AI analysis is being processed."),
        actions: [
          TextButton.icon(
             icon: const Icon(Icons.picture_as_pdf),
             label: const Text("Download Report"),
             onPressed: () async {
                final pdfBytes = await PdfService().generateScanReport(
                   scanData: {
                      'id': 'NEW-${DateTime.now().millisecondsSinceEpoch}',
                      'created_at': DateTime.now().toIso8601String(),
                      'prediction': 'Pending',
                      'confidence': 0.0,
                      ...formData,
                      'clinical_data': {
                          ...formData['clinical_data'],
                          'attachments': attachments?.map((f) => {'name': f.name, 'url': 'Attached'}).toList() ?? []
                      }
                   },
                   scanImageBytes: imageBytes ?? (await File(imagePath).readAsBytes()),
                );
                await Printing.sharePdf(bytes: pdfBytes, filename: 'EyeVLM_Report_New.pdf');
             },
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }
}
