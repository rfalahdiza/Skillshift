enum UserRole {
  learner,
  mentor,
  admin;

  static UserRole? tryParse(String? value) =>
      values.where((r) => r.name == value).firstOrNull;

  String get label => switch (this) {
    learner => 'Learner',
    mentor => 'Mentor',
    admin => 'Verifier',
  };
}

/// The signed-in user as the app sees it.
class AppSession {
  const AppSession({
    required this.userId,
    required this.email,
    this.fullName,
    this.role,
    this.isPreview = false,
  });

  final String userId;
  final String email;
  final String? fullName;

  /// Null until the user picks a role on L05 Choose Role.
  final UserRole? role;

  /// Debug-only offline preview of the shells (no Supabase session).
  final bool isPreview;

  String get displayName => (fullName == null || fullName!.isEmpty)
      ? email.split('@').first
      : fullName!;

  String get firstName => displayName.split(' ').first;
}
