import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';
import 'app_session.dart';

/// Current session: `AsyncLoading` while restoring, `AsyncData(null)` when
/// signed out.
final sessionProvider = AsyncNotifierProvider<SessionController, AppSession?>(
  SessionController.new,
);

/// Sign-in error with a message safe to show on screen.
class SignInException implements Exception {
  const SignInException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SessionController extends AsyncNotifier<AppSession?> {
  StreamSubscription<AuthState>? _authSub;

  SupabaseClient? get _client => ref.read(supabaseClientProvider);

  @override
  Future<AppSession?> build() async {
    final client = ref.watch(supabaseClientProvider);
    if (client == null) return null;

    _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen((event) async {
      if (state.value?.isPreview ?? false) return;
      if (event.event == AuthChangeEvent.tokenRefreshed) return;
      state = await AsyncValue.guard(() => _load(client));
    });
    ref.onDispose(() => _authSub?.cancel());

    return _load(client);
  }

  Future<AppSession?> _load(SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client
        .from('profiles')
        .select('full_name, role')
        .eq('id', user.id)
        .maybeSingle();
    return AppSession(
      userId: user.id,
      email: user.email ?? '',
      fullName: row?['full_name'] as String?,
      role: UserRole.tryParse(row?['role'] as String?),
    );
  }

  /// Re-read the profile (after choosing a role or editing the profile).
  Future<void> refresh() async {
    final client = _client;
    if (client == null || (state.value?.isPreview ?? false)) return;
    state = await AsyncValue.guard(() => _load(client));
  }

  /// L03: emails a 6-digit sign-in code. New UB users are created on the
  /// fly; the database rejects non-UB domains (handle_new_user trigger).
  Future<void> sendCode(String email) => _auth(() async {
    await _requireClient().auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: true,
    );
  });

  /// L04: checks the code. On success the auth listener loads the profile
  /// and the router moves on.
  Future<void> verifyCode(String email, String code) => _auth(() async {
    await _requireClient().auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: code,
      type: OtpType.email,
    );
  });

  /// Debug-only sign-in for seeded TEST accounts (@seed.skillshift.test),
  /// so the demo does not depend on email delivery.
  Future<void> demoSignIn(String email, String password) => _auth(() async {
    if (!kDebugMode) throw const SignInException('Not available.');
    await _requireClient().auth.signInWithPassword(
      email: email,
      password: password,
    );
  });

  SupabaseClient _requireClient() {
    final c = _client;
    if (c == null) {
      throw const SignInException(
        'Supabase is not configured. Add your .env and restart.',
      );
    }
    return c;
  }

  Future<void> _auth(Future<void> Function() run) async {
    try {
      await run();
    } on SignInException {
      rethrow;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('database error') || m.contains('only ub email')) {
        throw const SignInException(
          'Only UB student and staff email addresses can join SkillShift.',
        );
      }
      if (m.contains('expired') || m.contains('invalid')) {
        throw const SignInException(
          'That code is wrong or has expired. Check it or send a new one.',
        );
      }
      if (e.statusCode == '429' || m.contains('rate')) {
        throw const SignInException(
          'Too many attempts. Wait a minute and try again.',
        );
      }
      throw SignInException(e.message);
    } catch (_) {
      throw const SignInException(
        'Could not reach SkillShift. Check your connection.',
      );
    }
  }

  /// Saves the role chosen on L05. Admin cannot be self-assigned; the
  /// database rejects it too (see `profiles_guard_role` trigger).
  Future<void> chooseRole(UserRole role) async {
    assert(role != UserRole.admin, 'Admin role is assigned by the database');
    final current = state.value;
    if (current == null) return;
    if (current.isPreview) {
      state = AsyncData(_copy(current, role: role));
      return;
    }
    await _client!
        .from('profiles')
        .update({'role': role.name})
        .eq('id', current.userId);
    await refresh();
  }

  Future<void> signOut() async {
    if (state.value?.isPreview ?? false) {
      state = const AsyncData(null);
      return;
    }
    await _client?.auth.signOut();
    state = const AsyncData(null);
  }

  /// Debug-only offline preview of a role's shell, clearly labelled in the UI.
  void startPreview(UserRole role) {
    if (!kDebugMode) return;
    state = AsyncData(
      AppSession(
        userId: 'preview-${role.name}',
        email: 'preview@seed.skillshift.test',
        fullName: switch (role) {
          UserRole.learner => 'Nadia Putri',
          UserRole.mentor => 'Raka Pratama',
          UserRole.admin => 'Admin SkillShift',
        },
        role: role,
        isPreview: true,
      ),
    );
  }

  AppSession _copy(AppSession s, {UserRole? role}) => AppSession(
    userId: s.userId,
    email: s.email,
    fullName: s.fullName,
    role: role ?? s.role,
    isPreview: s.isPreview,
  );
}
