import 'package:flutter/material.dart';

/// Single source of truth for camera overlay dimensions.
/// Used by BOTH the overlay painter AND the image cropper to ensure
/// what the user sees (oval) matches what gets saved (rectangle).
class CameraOverlayConfig {
  // Oval dimensions relative to screen/image size
  static const double widthRatio = 0.85;   // 85% of width
  static const double heightRatio = 0.35;  // 35% of height (wider than tall for eye shape)
  static const double verticalCenterRatio = 0.35; // Positioned at upper 1/3 of screen
  
  /// Returns the bounding rectangle for the oval overlay.
  /// This rectangle FULLY ENCLOSES the oval, so cropping to this
  /// gives us a clean rectangular image without artificial edges.
  /// 
  /// [totalSize] - The size of the screen (for drawing) or image (for cropping)
  static Rect getCropRect(Size totalSize) {
    final double width = totalSize.width * widthRatio;
    final double height = totalSize.height * heightRatio;
    final double left = (totalSize.width - width) / 2;
    final double top = (totalSize.height * verticalCenterRatio) - (height / 2);
    
    return Rect.fromLTWH(left, top, width, height);
  }
  
  /// Get the oval Rect for drawing (same as crop rect since oval is inside rectangle)
  static Rect getOvalRect(Size screenSize) => getCropRect(screenSize);
  
  /// For debugging: returns the crop percentages
  static Map<String, double> getCropPercentages() {
    return {
      'widthRatio': widthRatio,
      'heightRatio': heightRatio,
      'verticalCenterRatio': verticalCenterRatio,
    };
  }
}
