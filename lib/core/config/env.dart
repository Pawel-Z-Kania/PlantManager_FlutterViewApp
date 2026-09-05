/// Centralna konfiguracja aplikacji. Wartości domyślne = obecne dane produkcyjne,
/// ale można je nadpisać przy buildzie: `flutter run --dart-define-from-file=env.json`.
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vkpxmvmthcdakeomseaf.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_457NI-KNXQINDcX3R5dFBg_uR3U40bi',
  );

  static const vercelApiUrl = String.fromEnvironment(
    'VERCEL_API_URL',
    defaultValue: 'https://plant-manager-server-backend.vercel.app',
  );
}
