import 'dart:io';

import 'dart:ui' show Size; // For Size class
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:eyevlm_app/core/config/camera_overlay_config.dart';

/// Service for processing images before upload.
/// Handles ROI cropping and compression.
class ImageProcessor {
  /// Crops the raw camera image to the ROI (region of interest)
  /// defined by CameraOverlayConfig.
  /// 
  /// This ensures only the eye region is uploaded, reducing:
  /// - File size by ~90% (5MB -> 500KB)
  /// - AI inference time (smaller input)
  /// - Upload time
  /// 
  /// Returns a new File with the cropped, compressed image.
  static Future<File> cropToOverlay(File rawImage, {int quality = 100}) async {
    try {
      // 1. Read the raw bytes from the camera file
      final bytes = await rawImage.readAsBytes();
      
      // 2. Decode the image (Handling potential format errors)
      img.Image? original = img.decodeImage(bytes);
      if (original == null) throw Exception("Failed to decode camera image");

      // 3. Fix Orientation (Crucial for Mobile)
      // Most camera sensors (especially on older Androids) capture in Landscape natively.
      // If the image is wider than it is tall, we rotate it 90 degrees to match the Portrait UI.
      if (original.width > original.height) {
        original = img.copyRotate(original, angle: 90);
      }

      // 4. Calculate the Crop Area (The Math)
      // We rely on the Single Source of Truth: CameraOverlayConfig.
      // If the UI oval is 85% of screen width, we take 85% of the image width.
      int cropW = (original.width * CameraOverlayConfig.widthRatio).toInt();
      int cropH = (original.height * CameraOverlayConfig.heightRatio).toInt();
      
      // Calculate center coordinates to place the crop box perfectly
      int cropX = (original.width - cropW) ~/ 2;
      int cropY = (original.height - cropH) ~/ 2;

      // 5. Perform the Crop (In-Memory)
      img.Image cropped = img.copyCrop(
        original, 
        // Calculate scale factor to preserve aspect ratio
        double scale = targetMinSize / (cropped.width < cropped.height ? cropped.width : cropped.height);
        
        // Don't upscale crazy amounts (cap at 4x to avoid artifacts)
        if (scale > 4.0) scale = 4.0;
        
        if (scale > 1.0) {
           final newWidth = (cropped.width * scale).round();
           final newHeight = (cropped.height * scale).round();
           
           cropped = img.copyResize(
             cropped, 
             width: newWidth, 
             height: newHeight, 
             interpolation: img.Interpolation.bicubic
           );
           debugPrint("ImageProcessor: Upscaled to ${cropped.width}x${cropped.height}");
        }
      }
      
      // Encode as high-quality JPEG
      final Uint8List compressedBytes = Uint8List.fromList(
        img.encodeJpg(cropped, quality: quality)
      );
      
      debugPrint("ImageProcessor: Compressed size: ${(compressedBytes.length / 1024).toStringAsFixed(1)} KB");
      
      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFile = File('${tempDir.path}/eye_roi_$timestamp.jpg');
      await outputFile.writeAsBytes(compressedBytes);
      
      return outputFile;
    } catch (e) {
      debugPrint("ImageProcessor: Error cropping image: $e");
      return rawImage; // Fallback to original on error
    }
  }
  
  /// Compress an image without cropping (for gallery uploads after manual crop)
  static Future<File> compress(File image, {int quality = 85}) async {
    try {
      final bytes = await image.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      
      if (decoded == null) return image;
      
      final Uint8List compressedBytes = Uint8List.fromList(
        img.encodeJpg(decoded, quality: quality)
      );
      
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFile = File('${tempDir.path}/compressed_$timestamp.jpg');
      await outputFile.writeAsBytes(compressedBytes);
      
      debugPrint("ImageProcessor: Compressed ${(bytes.length / 1024).toStringAsFixed(1)} KB -> ${(compressedBytes.length / 1024).toStringAsFixed(1)} KB");
      
      return outputFile;
    } catch (e) {
      debugPrint("ImageProcessor: Compression error: $e");
      return image;
    }
  }
  
  /// Get the estimated file size reduction percentage
  static double getEstimatedReduction() {
    // With 85% x 35% crop = 29.75% of original area
    // Plus JPEG compression -> ~10% of original file size
    return 0.90; // 90% reduction
  }
}
