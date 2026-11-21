import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Initialise Supabase once at startup. No-op when `.env` values are missing,
/// so the app still runs (showing a "not configured" notice) without them.
Future<void> initSupabase() async {
  if (!Env.hasSupabase) return;
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // Accepts either the legacy anon key or the newer `sb_publishable_…` key.
    publishableKey: Env.supabaseAnonKey,
  );
}

/// Null when Supabase is not configured.
final supabaseClientProvider = Provider<SupabaseClient?>(
  (ref) => Env.hasSupabase ? Supabase.instance.client : null,
);
