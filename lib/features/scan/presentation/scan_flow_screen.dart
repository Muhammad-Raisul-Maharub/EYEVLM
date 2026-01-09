import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eyevlm_app/features/scan/presentation/smart_camera_screen.dart';
import 'package:eyevlm_app/features/scan/presentation/clinical_data_form.dart';
import 'package:eyevlm_app/features/scan/data/scan_repository.dart';
import 'package:eyevlm_app/core/theme/app_tokens.dart';
import 'package:eyevlm_app/core/utils/app_notifications.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eyevlm_app/core/providers/refresh_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Multi-image scan flow that allows:
/// 1. Capture multiple images (max 5)
/// 2. Optional manual cropping per image
/// 3. Preview gallery before clinical form
/// 4. Instant navigation
class ScanFlowScreen extends ConsumerStatefulWidget {
  const ScanFlowScreen({super.key});

  @override
  ConsumerState<ScanFlowScreen> createState() => _ScanFlowScreenState();
}

class _ScanFlowScreenState extends ConsumerState<ScanFlowScreen> {
  // List of captured images with their paths and bytes
  final List<_CapturedImage> _capturedImages = [];
  static const int maxImages = 5;
  
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_capturedImages.isEmpty ? "New Scan" : "Captured (${_capturedImages.length}/$maxImages)"),
        actions: [
          if (_capturedImages.isNotEmpty)
            TextButton.icon(
              onPressed: _capturedImages.isNotEmpty ? _proceedToForm : null,
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              label: const Text("Next", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _capturedImages.isEmpty
              ? _buildCaptureOptions()
              : _buildImageGallery(),
      floatingActionButton: _capturedImages.isNotEmpty && _capturedImages.length < maxImages
          ? Padding(
              padding: const EdgeInsets.only(bottom: 65), // Increased to 65px as requested
              child: FloatingActionButton.extended(
                onPressed: _showAddMoreOptions,
                backgroundColor: AppColors.lightPrimary,
                icon: const Icon(Icons.add_a_photo),
                label: const Text("Add More"),
              ),
            )
          : null,
    );
  }

  /// Initial screen with capture options
  Widget _buildCaptureOptions() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon and Title
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.lightPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.remove_red_eye,
                size: 64,
                color: AppColors.lightPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Capture Eye Images",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You can capture up to $maxImages images per scan\nTap to crop manually if needed",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),
            
            // Camera Option
            _buildOptionCard(
              icon: Icons.camera_alt,
              title: "Live Camera",
              subtitle: "Take a new photo with auto-focus",
              color: Colors.purple,
              onTap: _openCamera,
            ),
            const SizedBox(height: 16),
            
            // Gallery Option
            _buildOptionCard(
              icon: Icons.photo_library,
              title: "Upload from Gallery",
              subtitle: "Choose an existing photo",
              color: Colors.orange,
              onTap: _pickFromGallery,
            ),
          ],
        ),
      ),
    );
  }

  /// Gallery view of captured images
  Widget _buildImageGallery() {
    return Column(
      children: [
        // Header info
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Tap image to crop • Tap ✕ to remove",
                  style: TextStyle(color: Colors.green[800], fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        
        // Image Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _capturedImages.length,
            itemBuilder: (context, index) {
              final img = _capturedImages[index];
              return Stack(
                children: [
                  // Image with tap to crop
                  GestureDetector(
                    onTap: () => _cropImage(index),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: img.isCropped ? Colors.green : Colors.grey.shade300,
                          width: img.isCropped ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: img.bytes != null
                            ? Image.memory(img.bytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                            : Image.file(File(img.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                      ),
                    ),
                  ),
                  
                  // Cropped badge
                  if (img.isCropped)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.crop, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text("Cropped", style: TextStyle(color: Colors.white, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  
                  // Image number badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "#${index + 1}",
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  
                  // Remove button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                  
                  // Retake button
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _retakeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.refresh, color: Colors.orange, size: 18),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        
        // Bottom action bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _capturedImages.clear()),
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text("Clear All"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _capturedImages.isNotEmpty ? _proceedToForm : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text("Continue to Form"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.lightPrimary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5)),
          ],
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
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

  /// Open camera to capture new image
  Future<void> _openCamera() async {
    if (_capturedImages.length >= maxImages) {
      AppNotifications.showError(context, "Maximum $maxImages images allowed");
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => SmartCameraScreen(
          onImageCaptured: (path) {
            Navigator.pop(context, path);
          },
        ),
      ),
    );

    if (result != null && mounted) {
      final bytes = await File(result).readAsBytes();
      setState(() {
        _capturedImages.add(_CapturedImage(path: result, bytes: bytes, isCropped: false));
      });
    }
  }

  /// Pick image from gallery
  Future<void> _pickFromGallery() async {
    if (_capturedImages.length >= maxImages) {
      AppNotifications.showError(context, "Maximum $maxImages images allowed");
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null && mounted) {
        final bytes = await File(image.path).readAsBytes();
        setState(() {
          _capturedImages.add(_CapturedImage(path: image.path, bytes: bytes, isCropped: false));
        });
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, "Error picking image: $e");
      }
    }
  }

  /// Show options to add more images
  void _showAddMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.purple,
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text("Camera"),
              onTap: () {
                Navigator.pop(context);
                _openCamera();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text("Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Crop a specific image
  Future<void> _cropImage(int index) async {
    final img = _capturedImages[index];
    
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: img.path,
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
        WebUiSettings(context: context),
      ],
    );

    if (croppedFile != null && mounted) {
      final bytes = await croppedFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _capturedImages[index] = _CapturedImage(
          path: croppedFile.path,
          bytes: bytes,
          isCropped: true,
        );
      });
      AppNotifications.showSuccess(context, "Image cropped successfully!");
    }
  }

  /// Remove an image
  void _removeImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
  }

  /// Retake a specific image
  Future<void> _retakeImage(int index) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => SmartCameraScreen(
          onImageCaptured: (path) {
            Navigator.pop(context, path);
          },
        ),
      ),
    );

    if (result != null && mounted) {
      final bytes = await File(result).readAsBytes();
      setState(() {
        _capturedImages[index] = _CapturedImage(path: result, bytes: bytes, isCropped: false);
      });
    }
  }

  /// Navigate to clinical data form
  Future<void> _proceedToForm() async {
    if (_capturedImages.isEmpty) {
      AppNotifications.showError(context, "Please capture at least one image");
      return;
    }

    final imagePaths = _capturedImages.map((e) => e.path).toList();
    final imageBytesList = _capturedImages.map((e) => e.bytes!).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClinicalDataForm(
          imagePaths: imagePaths,
          imageBytesList: imageBytesList,
          onSubmit: (formData, files) => _submitData(formData, files, imagePaths, imageBytesList),
        ),
      ),
    );
  }

  /// Submit data to repository
  Future<void> _submitData(
    Map<String, dynamic> formData,
    List<PlatformFile>? attachments,
    List<String> imagePaths,
    List<Uint8List> imageBytesList,
  ) async {
    setState(() => _isLoading = true);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.lightPrimary),
      ),
    );

    try {
      // Add timeout protection to prevent infinite waiting
      await ScanRepository().submitScan(
        imagePaths: imagePaths,
        formData: formData,
        attachments: attachments,
        imageBytesList: imageBytesList,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Submission timed out. The scan was saved locally and will sync when connection improves.'),
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        AppNotifications.showSuccess(context, "Scan uploaded successfully!");
        _showSuccessDialog(formData, imagePaths, imageBytesList);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // ALWAYS close loading dialog
        AppNotifications.showError(context, "Error: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> formData, List<String> imagePaths, List<Uint8List> imageBytesList) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text("Scan Submitted!"),
          ],
        ),
        content: Text("${imagePaths.length} image(s) uploaded.\nThe AI analysis is being processed."),
        actions: [
          // Download button removed as per user request
          ElevatedButton.icon(
            icon: const Icon(Icons.history),
            label: const Text("View in History"),
            onPressed: () {
              // Trigger reload in HistoryScreen
              ref.read(historyRefreshProvider.notifier).trigger();
              Navigator.of(context).pop(); // Close dialog
              context.go('/history');
            },
          ),
        ],
      ),
    );
  }
}

/// Model for captured image
class _CapturedImage {
  final String path;
  final Uint8List? bytes;
  final bool isCropped;

  _CapturedImage({
    required this.path,
    this.bytes,
    required this.isCropped,
  });
}
