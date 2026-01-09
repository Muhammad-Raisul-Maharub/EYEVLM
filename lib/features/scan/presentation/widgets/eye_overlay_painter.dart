import 'package:flutter/material.dart';

class EyeOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark Background
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7); // Updated from withOpacity

    // 2. The "Cutout" (Clear Oval)
    final cutoutPaint = Paint()
      ..blendMode = BlendMode.clear;

    // 3. The Border (Teal Ring)
    final borderPaint = Paint()
      ..color = const Color(0xFF00BFA5) // Teal accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw full screen background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Calculate Oval dimensions (80% width, 0.6 aspect ratio)
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final ovalWidth = size.width * 0.85; // Slightly wider for eye
    final ovalHeight = ovalWidth * 0.65;
    
    final ovalRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: ovalWidth,
      height: ovalHeight,
    );

    // Cut out the hole properly by using a SaveLayer (needed for BlendMode.clear to work on top of background)
    // Actually, simply drawing the rect first then the clear oval works in a single layer if using srcOut? 
    // But CustomPainter composes on top. 
    // Standard way: Draw transparent layer? 
    // Easier: Use a Path.
    
    // Better Approach: Path.combine (difference)
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final ovalPath = Path()
      ..addOval(ovalRect);
      
    final weirdPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      ovalPath,
    );
    
    canvas.drawPath(weirdPath, backgroundPaint);

    // Draw the border ring
    canvas.drawOval(ovalRect, borderPaint);
    
    // Draw Guidelines (Crosshair)
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
      
    // Horizontal Line
    canvas.drawLine(
      Offset(centerX - 20, centerY),
      Offset(centerX + 20, centerY),
      guidePaint,
    );
    
    // Vertical Line
    canvas.drawLine(
      Offset(centerX, centerY - 20),
      Offset(centerX, centerY + 20),
      guidePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
