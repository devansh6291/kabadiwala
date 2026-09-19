import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF66BB6A);
  static const Color primaryYellow = Color(0xFFF9A825);
  static const Color accent = Color(0xFFE8A33D);
  static const Color background = Color(0xFFFFFDF5);
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF5C5C5C);
  static const Color divider = Color(0xFFE0E0E0);

  static const Color success = Color(0xFF2E7D32);
  static const Color pending = Color(0xFFF9A825);
  static const Color error = Color(0xFFC62828);
  static const Color statusFailed = error;

  /// Badge color for a Lot's syncStatus: "pending" / "synced" / "failed".
  static Color forSyncStatus(String status) {
    switch (status) {
      case 'synced':
        return success;
      case 'failed':
        return error;
      case 'pending':
      default:
        return pending;
    }
  }

  /// Badge color for a ClassificationResult's condition: "good" / "bad".
  static Color forCondition(String condition) {
    switch (condition) {
      case 'bad':
        return error;
      case 'good':
      default:
        return success;
    }
  }
}
