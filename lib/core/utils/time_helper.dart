import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class TimeHelper {
  TimeHelper._();

  /// Mengambil waktu saat ini dalam zona WIB (UTC+7)
  static DateTime get nowWib {
    return DateTime.now().toUtc().add(const Duration(hours: 7));
  }

  /// Memeriksa apakah saat ini berada dalam rentang jam operasional resmi
  /// (Senin - Jumat, 08:00 - 15:00 WIB)
  static bool isWithinStandardHours() {
    final now = nowWib;
    // weekday: 1 = Senin, ..., 5 = Jumat, 6 = Sabtu, 7 = Minggu
    final isWeekday = now.weekday >= DateTime.monday && now.weekday <= DateTime.friday;
    final isTimeInRange = now.hour >= AppConstants.openHour && now.hour < AppConstants.closeHour;
    return isWeekday && isTimeInRange;
  }

  /// Menentukan apakah mahasiswa diizinkan mengambil antrean.
  /// Berdasarkan instruksi, tombol pengambilan tiket SELALU diizinkan (24 jam)
  /// agar mudah diuji coba/demo kapan saja oleh penguji maupun mahasiswa.
  static bool isQueueTakingAllowed() {
    return true;
  }

  /// Label status operasional untuk ditampilkan di kartu beranda
  static String getOperatingStatusBadge() {
    if (isWithinStandardHours()) {
      return 'Pelayanan Buka';
    } else {
      return 'Di Luar Jam Layanan (Mode Demo Aktif)';
    }
  }

  /// Informasi deskriptif jadwal pelayanan
  static String getOperatingHoursDescription() {
    return '${AppConstants.operationalDays}, ${AppConstants.operationalHours}';
  }

  /// Format tanggal Indonesia: "Senin, 24 November 2026"
  static String formatIndonesianDate(DateTime dateTime) {
    try {
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dateTime);
    } catch (_) {
      // Fallback jika locale id belum di-initialize
      return DateFormat('EEEE, d MMMM yyyy').format(dateTime);
    }
  }

  /// Format jam dan menit: "09:30 WIB"
  static String formatTimeWib(DateTime dateTime) {
    final wib = dateTime.toUtc().add(const Duration(hours: 7));
    final timeStr = DateFormat('HH:mm').format(wib);
    return '$timeStr WIB';
  }
}
