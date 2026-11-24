class SupabaseConfig {
  SupabaseConfig._();

  /// URL Proyek Supabase
  /// Dibaca dari compile-time environment variable (--dart-define=SUPABASE_URL=...)
  /// dengan fallback ke kredensial proyek Supabase resmi ULT FKIP.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xtrluwtwqkjretavurzc.supabase.co',
  );

  /// Anon/Publishable Key Supabase
  /// Dibaca dari compile-time environment variable (--dart-define=SUPABASE_ANON_KEY=...)
  /// dengan fallback ke anon key aman publik proyek ULT FKIP.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Osjrt36ieg9VRSaMJp1AIA_GJq3YTMz',
  );
}
