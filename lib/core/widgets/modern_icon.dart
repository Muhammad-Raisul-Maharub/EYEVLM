import 'package:flutter/material.dart';
import 'package:eyevlm_app/core/theme/app_tokens.dart';

/// A professional icon wrapper that adds consistent styling.
/// Use this instead of raw Icon() to achieve "App Store" quality icons.
class ModernIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const ModernIcon({
    super.key,
    required this.icon,
    this.onTap,
    this.isActive = false,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = activeColor ?? AppTokens.brandPrimary;
    final secondaryColor = inactiveColor ?? Colors.grey.shade700;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12), // Rule 1: Always add breathing room
        decoration: BoxDecoration(
          // Rule 2: Soft Background (Glassmorphism or Soft Tint)
          color: isActive
              ? primaryColor.withAlpha(38) // 0.15 * 255 ≈ 38
              : Colors.grey.withAlpha(13), // 0.05 * 255 ≈ 13
          borderRadius: BorderRadius.circular(12), // Rule 3: Consistent Radius
          border: isActive
              ? Border.all(color: primaryColor.withAlpha(128)) // 0.5 * 255 ≈ 128
              : null,
        ),
        child: Icon(
          icon,
          // Rule 4: Consistent Size & Color
          size: size,
          color: isActive ? primaryColor : secondaryColor,
        ),
      ),
    );
  }
}

/// A simpler icon button with modern styling (no background container)
class ModernIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final String? tooltip;

  const ModernIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.color,
    this.size = 24,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: size,
      color: color ?? AppTokens.brandPrimary,
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: iconWidget,
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: iconWidget,
      ),
    );
  }
}
