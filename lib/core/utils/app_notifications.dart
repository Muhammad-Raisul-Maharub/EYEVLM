import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyevlm_app/core/theme/app_tokens.dart';

class AppNotifications {
  /// Shows a Success SnackBar (Green)
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.teal.shade700,
      icon: Icons.check_circle_outline,
    );
  }

  /// Shows an Error SnackBar (Red)
  static void showError(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.red.shade700,
      icon: Icons.error_outline,
    );
  }

  /// Shows an Info SnackBar (App Primary Color)
  static void showInfo(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      backgroundColor: AppColors.lightPrimary, // Using updated token name
      icon: Icons.info_outline,
    );
  }

  static void _showSnackBar(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required IconData icon,
  }) {
    // Clear any existing snackbars to prevent overlapping/queueing
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // Floating margin for better UX on web/tablets
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
