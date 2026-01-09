import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../../../../core/config/camera_overlay_config.dart';
import '../../../../core/services/image_processor.dart';
import 'widgets/eye_overlay_painter.dart';

class SmartCameraScreen extends StatefulWidget {
  final Function(String path) onImageCaptured;

  const SmartCameraScreen({super.key, required this.onImageCaptured});

  @override
  _SmartCameraScreenState createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends State<SmartCameraScreen> {
  CameraController? _controller;
  bool _isFlashOn = false;
  bool _isProcessing = false;
  final ImageProcessor _processor = ImageProcessor();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    
    // Prefer Back Camera
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    // SAFETY MECHANISM: Try High Res, Fallback to Medium if it fails
    for (final preset in [ResolutionPreset.veryHigh, ResolutionPreset.high, ResolutionPreset.medium]) {
      try {
        _controller = CameraController(
          camera,
          preset, 
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        
        await _controller!.initialize();
        break; // It worked! Stop trying.
      } catch (e) {
        debugPrint("Resolution $preset failed: $e");
        continue; // Try the next lower resolution
      }
    }
    
    if (_controller == null || !_controller!.value.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Camera Error: Could not initialize")));
      }
      return;
    }

    try {
      await _controller!.setFocusMode(FocusMode.auto);
    } catch (_) {}
    
    if (mounted) setState(() {});
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    
    setState(() => _isFlashOn = !_isFlashOn);
    
    try {
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off
      );
    } catch (e) {
      debugPrint("Error toggling flash: $e");
    }
  }

  Future<void> _capture() async {
    if (_controller == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // 1. Capture Low-Noise Image
      final XFile rawFile = await _controller!.takePicture();
      
      // 2. Crop & Process using robust logic
      final File processedImage = await _processor.processHighQualityCrop(File(rawFile.path));

      // 3. Keep Flash On if user wanted it (Torch mode stays on), or turn off?
      // Usually better to leave it as is if user set it. 
      // But if we navigate away, dispose will handle it.

      // 4. Return Data
      if (mounted) {
        // Return result via callback or pop depending on navigation flow
        // The previous code used onImageCaptured callback, so we use that.
        widget.onImageCaptured(processedImage.path);
        Navigator.pop(context); 
      }

    } catch (e) {
      debugPrint("Capture Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Capture failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full Screen Camera Preview
          Center(child: CameraPreview(_controller!)),

          // 2. The Oval Guide (Custom Painter)
          CustomPaint(
            painter: EyeOverlayPainter(),
            child: Container(),
          ),

          // 3. User Instructions
          Positioned(
            top: 100, left: 20, right: 20,
            child: Text(
              "Keep the eye steady inside the oval.\nTurn on Flash for clearer results.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white, 
                fontSize: 16, 
                shadows: [Shadow(color: Colors.black, blurRadius: 4)]
              ),
            ),
          ),

          // 4. Controls Bottom Sheet
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Flash Button
                IconButton(
                  icon: Icon(
                    _isFlashOn ? Icons.highlight : Icons.flash_off, 
                    color: _isFlashOn ? Colors.yellow : Colors.white, 
                    size: 30
                  ),
                  onPressed: _toggleFlash,
                ),

                // Shutter Button (Manual Capture)
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 75, height: 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.teal, width: 4),
                    ),
                    child: _isProcessing 
                      ? const Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator()) 
                      : const Icon(Icons.camera_alt, color: Colors.teal, size: 35),
                  ),
                ),

                // Back Button (Cancel)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
