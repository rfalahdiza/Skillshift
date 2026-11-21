import 'models.dart';

/// Everything the learner screens need. Two implementations:
/// [SupabaseRepository] (real backend) and [SampleRepository] (offline,
/// debug-only preview with fake data).
abstract interface class SkillShiftRepository {
  Future<List<Course>> courses();

  /// Verified mentors per course id (for "4 mentors" on Home).
  Future<Map<String, int>> mentorCounts();

  Future<List<TimetableEntry>> myTimetable();
  Future<TimetableEntry> addTimetableEntry(TimetableDraft draft);
  Future<void> deleteTimetableEntry(String id);

  Future<LearnerPreference?> preference(String courseId);

  /// Saves the quiz answer; the server turns [openAnswer] into AI tags.
  Future<LearnerPreference> savePreference({
    required String courseId,
    required LearningStyle style,
    String? openAnswer,
  });

  /// Top 3 mentors for [courseId] (rule-based, with AI one-line reasons).
  Future<MatchResult> findMatches(String courseId, {int? maxPrice});

  Future<List<Booking>> myBookings();
  Future<Booking> requestBooking(BookingRequest request);
}

/// Error with a message that is safe to show to the user.
class UserFacingException implements Exception {
  const UserFacingException(this.message);
  final String message;

  @override
  String toString() => message;
}
