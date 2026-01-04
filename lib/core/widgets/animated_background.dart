import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:eyevlm_app/core/theme/app_tokens.dart'; // Ensure AppColors is available (same file)

class AnimatedBackground extends StatefulWidget {
  final Widget? child;
  const AnimatedBackground({super.key, this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // This makes the animation loop back and forth every 6 seconds
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We use AnimatedBuilder to redraw only the moving parts efficiently
    return Stack(
      children: [
        // 1. The Base Color (Dark or Light based on theme)
        Container(color: Theme.of(context).scaffoldBackgroundColor),

        // 2. The Moving Blobs
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                // Top Left Blob (Moves slowly right/down)
                Positioned(
                  top: -50 + (_controller.value * 30), 
                  left: -50 + (_controller.value * 20),
                  child: _buildBlob(AppColors.lightPrimary.withAlpha(77)),
                ),
                // Bottom Right Blob (Moves slowly left/up)
                Positioned(
                  bottom: -50 + (_controller.value * 40),
                  right: -50 + (_controller.value * 30),
                  child: _buildBlob(Colors.blueAccent.withAlpha(51)),
                ),
              ],
            );
          },
        ),

        // 3. The "Glass" Filter (Blurs the blobs for a smooth look)
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.transparent),
          ),
        ),

        // 4. The Actual Content
        if (widget.child != null) SafeArea(child: widget.child!),
      ],
    );
  }

  Widget _buildBlob(Color color) {
    return Container(
      height: 300,
      width: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
