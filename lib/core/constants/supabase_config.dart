class SupabaseConfig {
  SupabaseConfig._();

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// URL Proyek Supabase
  /// Dibaca dari compile-time environment variable (--dart-define=SUPABASE_URL=...)
  /// dengan fallback ke kredensial proyek Supabase resmi ULT FKIP jika kosong.
  static String get url => _envUrl.trim().isNotEmpty
      ? _envUrl.trim()
      : 'https://xtrluwtwqkjretavurzc.supabase.co';

  /// Anon/Publishable Key Supabase
  /// Dibaca dari compile-time environment variable (--dart-define=SUPABASE_ANON_KEY=...)
  /// dengan fallback ke anon key aman publik proyek ULT FKIP jika kosong.
  static String get anonKey => _envAnonKey.trim().isNotEmpty
      ? _envAnonKey.trim()
      : 'sb_publishable_Osjrt36ieg9VRSaMJp1AIA_GJq3YTMz';
}
