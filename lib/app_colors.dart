import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF66BB6A);
  static const Color primaryYellow = Color(0xFFF9A825);
  static const Color background = Color(0xFFFFFDF5);
    // syncStatus badge colors — "pending" / "synced" / "failed"
  static const Color statusPending = Color(0xFFF9A825);
  static const Color statusSynced = Color(0xFF2E7D32);
  static const Color statusFailed = Color(0xFFC62828);

  static Color forSyncStatus(String syncStatus) {
    switch (syncStatus) {
      case 'synced':
        return statusSynced;
      case 'failed':
        return statusFailed;
      case 'pending':
      default:
        return statusPending;
    }
  }
}