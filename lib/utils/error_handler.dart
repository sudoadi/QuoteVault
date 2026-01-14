import 'package:flutter/material.dart';

class ErrorHandler {
  static void show(BuildContext context, String message, {bool isError = true}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static String parse(Object e) {
    // simplify Supabase/Network errors into user-friendly strings
    final msg = e.toString();
    if (msg.contains("SocketException")) return "Network connection lost.";
    if (msg.contains("AuthException")) return "Authentication failed.";
    return "An unexpected error occurred.";
  }
}