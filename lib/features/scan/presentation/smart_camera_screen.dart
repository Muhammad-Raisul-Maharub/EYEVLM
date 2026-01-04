import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eyevlm_app/core/theme/app_tokens.dart';

class SmartCameraScreen extends StatefulWidget {
  final Function(String path) onImageCaptured;

  const SmartCameraScreen({super.key, required this.onImageCaptured});

  @override
  State<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends State<SmartCameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // Needed for Eye Open probability
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  String _statusMessage = "Initializing...";
  Color _statusColor = Colors.red;
  
  // Logic State
  bool _eyesOpen = false;
  bool _faceCentered = false;
  int _goodFramesCount = 0; // To track "steadiness"

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _updateStatus("Camera permission denied", Colors.red);
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _updateStatus("No cameras available", Colors.red);
        return;
      }

      // Find the back camera (higher res for medical imaging)
      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high, // High Res for Data Collection
        enableAudio: false,
        imageFormatGroup: kIsWeb || Platform.isAndroid 
            ? ImageFormatGroup.nv21 
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      // Start the Image Stream for ML Analysis
      await _controller!.startImageStream(_processCameraImage);
      _updateStatus("Position your eye in the frame", Colors.orange);
    } on CameraException catch (e) {
      debugPrint("Camera error: ${e.code} - ${e.description}");
      String message = "Camera error: ${e.description}";
      if (e.code == 'cameraNotReadable' || e.code == 'CameraAccessDenied') {
         message = "Camera is busy or access denied. Please close other apps using the camera and refresh.";
      }
      _updateStatus(message, Colors.red);
    } catch (e) {
      debugPrint("Camera initialization error: $e");
      _updateStatus("Camera error: $e", Colors.red);
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _isCapturing) return; // Drop frames if busy
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        _updateStatus("No face detected - Position your face", Colors.red);
        _resetStability();
      } else {
        // We only care about the biggest face (closest to camera)
        final face = faces.first;
        _validateFace(face, image.width.toDouble(), image.height.toDouble());
      }
    } catch (e) {
      debugPrint("Error processing face: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _validateFace(Face face, double imgWidth, double imgHeight) {
    // 1. Check Eyes Open (Probability 0.0 to 1.0)
    final double leftOpen = face.leftEyeOpenProbability ?? 0.0;
    final double rightOpen = face.rightEyeOpenProbability ?? 0.0;
    
    // Threshold: 0.4+ means eyes are reasonably open
    bool eyesOpen = (leftOpen > 0.4 || rightOpen > 0.4);

    // 2. Check Face is Centered (within middle 60% of frame)
    final boundingBox = face.boundingBox;
    double faceWidth = boundingBox.width;
    
    // Check if face is large enough (at least 15% of image width)
    bool faceLargeEnough = faceWidth > (imgWidth * 0.15);
    
    // Check if face is centered
    double centerX = boundingBox.center.dx;
    double centerY = boundingBox.center.dy;
    bool centeredX = centerX > imgWidth * 0.2 && centerX < imgWidth * 0.8;
    bool centeredY = centerY > imgHeight * 0.2 && centerY < imgHeight * 0.8;
    bool centered = centeredX && centeredY && faceLargeEnough;

    // 3. Update State
    if (mounted) {
      setState(() {
        _eyesOpen = eyesOpen;
        _faceCentered = centered;
      });
    }

    if (!faceLargeEnough) {
      _updateStatus("Move closer to the camera", Colors.orange);
      _resetStability();
    } else if (!eyesOpen) {
      _updateStatus("Open your eyes wider!", Colors.orange);
      _resetStability();
    } else if (!centered) {
      _updateStatus("Center your face in the frame", Colors.orange);
      _resetStability();
    } else {
      // ALL CONDITIONS MET!
      _goodFramesCount++;
      
      if (_goodFramesCount < 5) {
        _updateStatus("Hold steady... ${5 - _goodFramesCount}", Colors.green.shade400);
      } else if (_goodFramesCount < 10) {
        _updateStatus("Perfect! Capturing...", Colors.green);
      }

      // If good for ~10 frames (~0.5-1 second), auto-capture
      if (_goodFramesCount >= 10 && !_isCapturing) {
        _takePicture();
      }
    }
  }

  void _resetStability() {
    _goodFramesCount = 0;
  }

  void _updateStatus(String msg, Color color) {
    if (mounted && (_statusMessage != msg || _statusColor != color)) {
      setState(() {
        _statusMessage = msg;
        _statusColor = color;
      });
    }
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _isCapturing) return;
    
    _isCapturing = true;
    _updateStatus("Capturing high-res image...", Colors.green);
    
    try {
      // Stop stream first to free up camera for high-res capture
      await _controller!.stopImageStream();
      
      final XFile file = await _controller!.takePicture();
      
      if (mounted) {
        widget.onImageCaptured(file.path);
      }
    } catch (e) {
      debugPrint("Error capturing: $e");
      _updateStatus("Capture failed. Try again.", Colors.red);
      _isCapturing = false;
      // Restart stream if capture failed
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.startImageStream(_processCameraImage);
      }
    }
  }

  // --- Helper: Convert CameraImage to ML Kit InputImage ---
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    // Get camera rotation
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == _controller!.description.lensDirection,
      orElse: () => _cameras.first,
    );
    
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      // Android rotation calculation
      var rotationCompensation = _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      
      if (camera.lensDirection == CameraLensDirection.front) {
        // Front camera
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // Back camera
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    
    if (rotation == null) return null;

    // Get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    
    // NV21 and BGRA are supported
    if (format == null || 
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    // Validate plane data
    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  // Rotation map for Android
  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void dispose() {
    _faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.lightPrimary),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full Screen Camera Preview
          SizedBox.expand(
            child: CameraPreview(_controller!),
          ),

          // 2. Overlay Guide (The Dynamic Color Box)
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 280,
              height: 350,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _statusColor, 
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: _statusColor == Colors.green
                    ? [BoxShadow(color: Colors.green.withAlpha(100), blurRadius: 20, spreadRadius: 2)]
                    : null,
              ),
            ),
          ),

          // 3. Corner Markers for Professional Look
          Center(
            child: SizedBox(
              width: 300,
              height: 370,
              child: Stack(
                children: [
                  _buildCorner(Alignment.topLeft),
                  _buildCorner(Alignment.topRight),
                  _buildCorner(Alignment.bottomLeft),
                  _buildCorner(Alignment.bottomRight),
                ],
              ),
            ),
          ),

          // 4. Top Status Bar
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _eyesOpen ? Icons.visibility : Icons.visibility_off,
                      color: _eyesOpen ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _eyesOpen ? "Eyes Open" : "Eyes Closed",
                      style: TextStyle(
                        color: _eyesOpen ? Colors.green : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      _faceCentered ? Icons.center_focus_strong : Icons.center_focus_weak,
                      color: _faceCentered ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _faceCentered ? "Centered" : "Off-center",
                      style: TextStyle(
                        color: _faceCentered ? Colors.green : Colors.orange,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Status Message at Bottom
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color: _statusColor.withAlpha(200),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          
          // 6. Manual Override Button
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Back Button
                FloatingActionButton(
                  heroTag: "back",
                  backgroundColor: Colors.white24,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 40),
                // Manual Capture Button
                FloatingActionButton.large(
                  heroTag: "capture",
                  backgroundColor: AppColors.lightPrimary,
                  onPressed: _isCapturing ? null : () => _takePicture(),
                  child: _isCapturing 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 40),
                // Switch Camera Button
                FloatingActionButton(
                  heroTag: "switch",
                  backgroundColor: Colors.white24,
                  onPressed: _switchCamera,
                  child: const Icon(Icons.flip_camera_ios, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? BorderSide(color: _statusColor, width: 3)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                ? BorderSide(color: _statusColor, width: 3)
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? BorderSide(color: _statusColor, width: 3)
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                ? BorderSide(color: _statusColor, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    
    final currentDirection = _controller!.description.lensDirection;
    CameraDescription newCamera;
    
    if (currentDirection == CameraLensDirection.back) {
      newCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
    } else {
      newCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
    }
    
    await _controller!.stopImageStream();
    await _controller!.dispose();
    
    _controller = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.nv21 
          : ImageFormatGroup.bgra8888,
    );
    
    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);
    
    if (mounted) setState(() {});
  }
}
