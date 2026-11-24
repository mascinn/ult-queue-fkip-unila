import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Warna Utama Identitas FKIP Unila (Ungu & Putih)
  static const Color primary = Color(0xFF810081);       // Ungu Khas FKIP Unila
  static const Color primaryDark = Color(0xFF560056);   // Ungu Tua Elegan
  static const Color primaryLight = Color(0xFFF7EBF8);  // Ungu Sangat Lembut
  static const Color accentYellow = Color(0xFFF9D90A);  // Kuning Emas Logo FKIP
  static const Color accentOrange = Color(0xFFE65100);

  // Background & Permukaan (Dominan Putih Bersih)
  static const Color background = Color(0xFFFAF9FB);   // Putih Bersih
  static const Color surface = Colors.white;            // Putih Murni
  static const Color cardBorder = Color(0xFFEADDEC);    // Border Halus

  // Teks
  static const Color textPrimary = Color(0xFF211526);
  static const Color textSecondary = Color(0xFF6B5D70);
  static const Color textMuted = Color(0xFF9E91A3);

  // Warna Status Antrean
  static const Color statusWaiting = Color(0xFFD97706);    // Amber
  static const Color statusCalled = Color(0xFF810081);     // Ungu FKIP (Panggilan Aktif)
  static const Color statusInService = Color(0xFF9333EA);  // Ungu Sedang Layani
  static const Color statusCompleted = Color(0xFF059669);  // Hijau
  static const Color statusSkipped = Color(0xFFDC2626);    // Merah

  // Background Status Lembut (Pill/Badge)
  static const Color statusWaitingBg = Color(0xFFFEF3C7);
  static const Color statusCalledBg = Color(0xFFF5E1F5);
  static const Color statusInServiceBg = Color(0xFFF3E8FF);
  static const Color statusCompletedBg = Color(0xFFD1FAE5);
  static const Color statusSkippedBg = Color(0xFFFEE2E2);

  // Helper untuk warna berdasarkan status
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'called':
        return statusCalled;
      case 'in_service':
        return statusInService;
      case 'completed':
        return statusCompleted;
      case 'skipped':
        return statusSkipped;
      case 'waiting':
      default:
        return statusWaiting;
    }
  }

  static Color getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'called':
        return statusCalledBg;
      case 'in_service':
        return statusInServiceBg;
      case 'completed':
        return statusCompletedBg;
      case 'skipped':
        return statusSkippedBg;
      case 'waiting':
      default:
        return statusWaitingBg;
    }
  }
}
