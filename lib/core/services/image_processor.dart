import 'dart:io';
import 'dart:typed_data';
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
      final bytes = await rawImage.readAsBytes();
      img.Image? original = img.decodeImage(bytes);
      
      if (original == null) {
        debugPrint("ImageProcessor: Failed to decode image, returning original");
        return rawImage; // Fallback to original
      }
      
      debugPrint("ImageProcessor: Original image size: ${original.width}x${original.height}");
      
      // ========== ROTATION HANDLING ==========
      // Mobile cameras often save landscape-oriented images even in portrait mode
      // If width > height, rotate 90 degrees to ensure portrait orientation
      if (original.width > original.height) {
        debugPrint("ImageProcessor: Rotating landscape image to portrait");
        original = img.copyRotate(original, angle: 90);
        debugPrint("ImageProcessor: After rotation: ${original.width}x${original.height}");
      }
      
      // Get the crop rect based on the IMAGE dimensions
      final imageSize = Size(original.width.toDouble(), original.height.toDouble());
      final cropRect = CameraOverlayConfig.getCropRect(imageSize);
      
      // Validate crop bounds
      final x = cropRect.left.toInt().clamp(0, original.width - 1);
      final y = cropRect.top.toInt().clamp(0, original.height - 1);
      final w = cropRect.width.toInt().clamp(1, original.width - x);
      final h = cropRect.height.toInt().clamp(1, original.height - y);
      
      debugPrint("ImageProcessor: Cropping to x:$x, y:$y, w:$w, h:$h");
      
      // Perform the crop
      img.Image cropped = img.copyCrop(
        original, 
        x: x, 
        y: y, 
        width: w, 
        height: h,
      );
      
      debugPrint("ImageProcessor: Cropped image size: ${cropped.width}x${cropped.height}");

      // ========== UPSCALING ==========
      // Ensure specific minimum resolution for AI (e.g., 1024px)
      // This preserves detail even when cropping small eyes
      const int targetMinSize = 1024;
      if (cropped.width < targetMinSize || cropped.height < targetMinSize) {
        debugPrint("ImageProcessor: Upscaling to target minimum $targetMinSize px");
        
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
