import 'package:flutter/material.dart';

enum SnackBarType { success, error, warning, info }

class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    required SnackBarType type,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    // Clear any active snackbars first
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Pick colors and icons based on message type
    Color backgroundColor;
    Color textColor = Colors.white;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = isDarkMode ? const Color(0xFF1B5E20) : const Color(0xFF2E7D32); // Premium greens
        icon = Icons.check_circle_outline_rounded;
        break;
      case SnackBarType.error:
        backgroundColor = isDarkMode ? const Color(0xFFB71C1C) : const Color(0xFFC62828); // Premium reds
        icon = Icons.error_outline_rounded;
        break;
      case SnackBarType.warning:
        backgroundColor = isDarkMode ? const Color(0xFFE65100) : const Color(0xFFEF6C00); // Premium orange
        icon = Icons.warning_amber_rounded;
        break;
      case SnackBarType.info:
        backgroundColor = isDarkMode ? const Color(0xFF0D47A1) : const Color(0xFF1565C0); // Premium blue
        icon = Icons.info_outline_rounded;
        break;
    }

    final snackBar = SnackBar(
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      elevation: 6.0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 90), // Shows higher than the bottom navigation bar!
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      duration: duration,
      content: Row(
        children: [
          Icon(
            icon,
            color: textColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Helper for slow internet warning
  static void showSlowInternet(BuildContext context) {
    show(
      context,
      message: 'Пайвастшавӣ суст аст. Лутфан интизор шавед...',
      type: SnackBarType.warning,
      duration: const Duration(milliseconds: 1800),
    );
  }
}
