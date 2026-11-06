import 'package:flutter/material.dart';

/// Visible snackbars on dark theme — fixes white bar with no readable text.
class AppSnackBar {
  static void show(BuildContext context, String message, {bool isError = false, bool isSuccess = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError
            ? Colors.redAccent.shade700
            : isSuccess
                ? Colors.green.shade700
                : const Color(0xFF1E88E5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }
}
