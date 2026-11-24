class AppConstants {
  AppConstants._();

  static const String appName = 'ULT Queue FKIP';
  static const String appTagline = 'Unit Layanan Terpadu FKIP Unila';
  static const String facultyName = 'Fakultas Keguruan dan Ilmu Pendidikan';
  static const String universityName = 'Universitas Lampung';

  // Jam Operasional
  static const String operationalDays = 'Senin – Jumat';
  static const String operationalHours = '08:00 – 15:00 WIB';
  static const int openHour = 8;
  static const int closeHour = 15;

  // Daftar Program Studi FKIP Unila (Pilihan Cepat untuk Mahasiswa)
  static const List<String> fkipStudyPrograms = [
    'Pendidikan Bahasa dan Sastra Indonesia',
    'Pendidikan Bahasa Inggris',
    'Pendidikan Bahasa Perancis',
    'Pendidikan Biologi',
    'Pendidikan Fisika',
    'Pendidikan Kimia',
    'Pendidikan Matematika',
    'Pendidikan Ekonomi',
    'Pendidikan Geografi',
    'Pendidikan Sejarah',
    'PPKn',
    'Pendidikan Jasmani (Penjas)',
    'PGSD',
    'PGPAUD',
    'Bimbingan dan Konseling (BK)',
    'Pendidikan Musik',
    'Pendidikan Tari',
    'Pendidikan Seni Rupa',
    'Pendidikan Teknologi Informasi',
  ];

  // Loket Default
  static const List<String> defaultCounters = [
    'Loket 1',
    'Loket 2',
    'Loket 3',
  ];
}
