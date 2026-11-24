import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Warna Utama Identitas Unila & FKIP
  static const Color primary = Color(0xFF005DAA);       // Biru Resmi Unila
  static const Color primaryDark = Color(0xFF003D73);   // Biru Tua Header
  static const Color primaryLight = Color(0xFFE8F1FA);  // Biru Lembut Background
  static const Color accentYellow = Color(0xFFFDB813);  // Kuning Emas FKIP
  static const Color accentOrange = Color(0xFFF37021);

  // Background & Permukaan
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Teks
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Warna Status Antrean
  static const Color statusWaiting = Color(0xFFF59E0B);    // Oranye / Amber
  static const Color statusCalled = Color(0xFF0284C7);     // Biru Langit
  static const Color statusInService = Color(0xFF8B5CF6);  // Ungu
  static const Color statusCompleted = Color(0xFF10B981);  // Hijau
  static const Color statusSkipped = Color(0xFFEF4444);    // Merah

  // Background Status Lembut (Pill/Badge)
  static const Color statusWaitingBg = Color(0xFFFEF3C7);
  static const Color statusCalledBg = Color(0xFFE0F2FE);
  static const Color statusInServiceBg = Color(0xFFEDE9FE);
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
