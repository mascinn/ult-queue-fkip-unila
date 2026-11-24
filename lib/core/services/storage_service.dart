import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyActiveTicketId = 'active_ticket_id';
  static const String _keyStudentName = 'student_name';
  static const String _keyStudentNpm = 'student_npm';
  static const String _keyStudentProdi = 'student_prodi';
  static const String _keyStaffCounter = 'staff_selected_counter';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // --- Tiket Aktif Mahasiswa ---
  static Future<void> setActiveTicketId(String ticketId) async {
    await init();
    await _prefs?.setString(_keyActiveTicketId, ticketId);
  }

  static String? getActiveTicketId() {
    return _prefs?.getString(_keyActiveTicketId);
  }

  static Future<void> clearActiveTicketId() async {
    await init();
    await _prefs?.remove(_keyActiveTicketId);
  }

  // --- Profil Mahasiswa (Cache) ---
  static Future<void> saveStudentProfile({
    required String name,
    required String npm,
    required String prodi,
  }) async {
    await init();
    await _prefs?.setString(_keyStudentName, name);
    await _prefs?.setString(_keyStudentNpm, npm);
    await _prefs?.setString(_keyStudentProdi, prodi);
  }

  static Map<String, String> getStudentProfile() {
    return {
      'name': _prefs?.getString(_keyStudentName) ?? '',
      'npm': _prefs?.getString(_keyStudentNpm) ?? '',
      'prodi': _prefs?.getString(_keyStudentProdi) ?? '',
    };
  }

  // --- Loket Petugas ---
  static Future<void> setStaffCounter(String counter) async {
    await init();
    await _prefs?.setString(_keyStaffCounter, counter);
  }

  static String getStaffCounter() {
    return _prefs?.getString(_keyStaffCounter) ?? 'Loket 1';
  }
}
