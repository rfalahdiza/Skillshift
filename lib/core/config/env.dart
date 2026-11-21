/// Compile-time client configuration.
///
/// Values come from `--dart-define-from-file=.env` (see `.env.example`).
/// Only public client values belong here: the Supabase URL and anon key are
/// safe to ship in an app because Row Level Security protects the data.
/// Server keys (Gemini, Midtrans server key, service role) live only in
/// Supabase Edge Function secrets.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Password for the seeded demo accounts (`*@seed.skillshift.test`).
  /// Only read in debug builds. Leave empty to hide the demo sign-in.
  static const demoPassword = String.fromEnvironment('DEMO_PASSWORD');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

/// Business rules shown in the UI. The database (`app_config` table and
/// triggers) is the source of truth; these are display defaults used until
/// the config row is loaded.
abstract final class AppDefaults {
  static const platformFeePercent = 10;
  static const priceMin = 15000;
  static const priceMax = 40000;
  static const freeTrialMinutes = 30;
  static const allowedEmailDomains = ['student.ub.ac.id', 'ub.ac.id'];
}
