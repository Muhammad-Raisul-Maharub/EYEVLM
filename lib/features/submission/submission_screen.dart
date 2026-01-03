import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/refresh_provider.dart';

import 'submission_service.dart';

// --- HELPER WIDGET FOR WEB/MOBILE IMAGES ---
class PlatformAwareImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  const PlatformAwareImage({super.key, required this.path, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(path, fit: fit, errorBuilder: (c, e, s) => const Icon(Icons.error));
    } else {
      return Image.file(File(path), fit: fit, errorBuilder: (c, e, s) => const Icon(Icons.error));
    }
  }
}

class SubmissionScreen extends ConsumerStatefulWidget {
  const SubmissionScreen({super.key});
  @override
  ConsumerState<SubmissionScreen> createState() => _SubmissionScreenState();
}

class _SubmissionScreenState extends ConsumerState<SubmissionScreen> {
  XFile? _selectedImage; // Use XFile to support both Web & Mobile
  bool _isAnalyzing = false;
  final TextEditingController _symptomsController = TextEditingController();

  // 1. PICK IMAGE ONLY (No Auto-Crop)
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _selectedImage = pickedFile);
    }
  }

  // 2. MANUAL CROP FUNCTION
  Future<void> _cropCurrentImage() async {
    if (_selectedImage == null) return;
    
    // Cropper requires a File path, works differently on web internally
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: _selectedImage!.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: const Color(0xFF009688),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
        WebUiSettings(context: context), // Required for Web
      ],
    );

    if (croppedFile != null) {
      setState(() => _selectedImage = XFile(croppedFile.path));
    }
  }

  // 3. ANALYZE FUNCTION (Real Backend Call)
  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;
    setState(() => _isAnalyzing = true);

    try {
      final submissionService = ref.read(submissionServiceProvider);
      
      // Step 1: Upload Image
      final imageUrl = await submissionService.uploadImage(_selectedImage!);
      
      // Step 2: Get Inference
      final result = await submissionService.submitInference(
        imageUrl: imageUrl,
        symptoms: _symptomsController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analysis Complete!')));
        
        // Inject URL and Symptoms into result for the Result Screen to use
        final finalResult = Map<String, dynamic>.from(result);
        finalResult['saved_image_url'] = imageUrl;
        finalResult['symptoms'] = _symptomsController.text.trim();

        // Trigger History Refresh
        ref.read(historyRefreshProvider.notifier).trigger();

        context.go('/result', extra: finalResult); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Analysis"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Capture Eye Image", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text("Ensure the eye is centered and well-lit.", style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),

            // UPLOAD ZONE
            GestureDetector(
              onTap: _isAnalyzing ? null : () => _showPickerOptions(context),
              child: DottedBorder(
                color: _selectedImage == null ? Colors.grey.shade400 : const Color(0xFF009688),
                strokeWidth: 2,
                dashPattern: const [8, 4],
                radius: const Radius.circular(20),
                borderType: BorderType.RRect,
                child: Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _selectedImage == null ? Colors.white : Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _selectedImage != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: PlatformAwareImage(path: _selectedImage!.path),
                            ),
                            if (_isAnalyzing)
                              Container(
                                color: const Color(0xFF009688).withAlpha(77),
                                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                              ),
                            if (!_isAnalyzing)
                              Positioned(
                                top: 10, right: 10,
                                child: Row(
                                  children: [
                                    // CROP BUTTON
                                    CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      child: IconButton(
                                        icon: const Icon(Icons.crop, color: Colors.white, size: 20),
                                        onPressed: _cropCurrentImage,
                                        tooltip: "Crop Image",
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // REMOVE BUTTON
                                    CircleAvatar(
                                      backgroundColor: Colors.red.withAlpha(204),
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                        onPressed: () => setState(() => _selectedImage = null),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text("Tap to Upload", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey[600])),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // SYMPTOMS INPUT
            TextField(
              controller: _symptomsController,
              decoration: const InputDecoration(
                labelText: "Symptoms (Optional)",
                hintText: "e.g., redness, itching, pain...",
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 30),
            
            // BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_isAnalyzing || _selectedImage == null) ? null : _analyzeImage,
                child: _isAnalyzing 
                  ? const Text("Analyzing...") 
                  : const Text("Analyze Scan"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.image), title: const Text('Gallery'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }
}
