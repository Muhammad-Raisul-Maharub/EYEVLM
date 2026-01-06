import 'dart:io';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Utility class for converting CameraImage to ML Kit InputImage.
/// This handles the complex math required for Google ML Kit to understand camera streams.
class CameraUtils {
  /// Converts a [CameraImage] from camera stream to ML Kit [InputImage].
  /// 
  /// [image] - The camera image from the stream
  /// [camera] - The camera description (for sensor orientation)
  /// [deviceOrientation] - Current device orientation
  /// 
  /// Returns [InputImage] if conversion succeeds, null otherwise.
  static InputImage? convert(
    CameraImage image, 
    CameraDescription camera,
    DeviceOrientation? deviceOrientation,
  ) {
    // Get rotation based on platform
    final InputImageRotation? rotation = _getRotation(
      camera.sensorOrientation,
      camera.lensDirection,
      deviceOrientation,
    );
    
    if (rotation == null) return null;

    // Get image format
    final InputImageFormat? format = _getImageFormat(image.format.raw);
    if (format == null) return null;

    // Validate planes
    if (image.planes.isEmpty) return null;

    // Build InputImage from bytes
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

  /// Alternative method using concatenated plane data (for some Android devices)
  static InputImage? convertWithAllPlanes(
    CameraImage image, 
    CameraDescription camera,
    DeviceOrientation? deviceOrientation,
  ) {
    final InputImageRotation? rotation = _getRotation(
      camera.sensorOrientation,
      camera.lensDirection,
      deviceOrientation,
    );
    
    if (rotation == null) return null;

    // Concatenate all plane bytes
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final InputImageFormat format = Platform.isAndroid 
        ? InputImageFormat.nv21 
        : InputImageFormat.bgra8888;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  static InputImageRotation? _getRotation(
    int sensorOrientation,
    CameraLensDirection lensDirection,
    DeviceOrientation? deviceOrientation,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (Platform.isAndroid) {
      // Android rotation calculation
      var rotationCompensation = _orientationMap[deviceOrientation];
      if (rotationCompensation == null) return null;

      if (lensDirection == CameraLensDirection.front) {
        // Front camera
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // Back camera
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      return InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    return null;
  }

  static InputImageFormat? _getImageFormat(int rawFormat) {
    // Android NV21 = 17, YUV_420_888 = 35
    // iOS BGRA8888 = 1111970369
    if (Platform.isAndroid) {
      return InputImageFormat.nv21;
    }
    if (Platform.isIOS) {
      return InputImageFormat.bgra8888;
    }
    return null;
  }

  static const Map<DeviceOrientation, int> _orientationMap = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
}
