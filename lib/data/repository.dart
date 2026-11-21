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

  // Phase 3 -----------------------------------------------------------------

  /// L12: creates the paid booking and a Midtrans SANDBOX transaction.
  Future<PaymentStart> startPaidBooking(
    BookingRequest request,
    PaymentMethod method,
  );

  /// L13: asks the server to check the payment with Midtrans.
  Future<PaymentState> checkPayment(String bookingId);

  /// L14 / L15.
  Future<SessionDetail> sessionDetail(String bookingId);
  Future<void> confirmAttendance(String bookingId);
  Future<void> cancelBooking(String bookingId);

  // Phase 4: mentor ---------------------------------------------------------

  Future<MentorOverview> mentorOverview();

  /// Suggested price range for a course (Rp per hour).
  Future<({int min, int max})> priceRange(String courseId);

  /// M01: uploads the KHS to the private bucket; returns its storage path.
  Future<String> uploadKhs(List<int> bytes, String fileName);
  Future<void> submitApplication(ApplicationDraft draft);

  /// M04: bookings where I am the mentor.
  Future<List<MentorBooking>> mentorBookings();
  Future<void> respondToBooking(String bookingId, {required bool accept});

  /// M05 (payouts are simulated).
  Future<Earnings> earnings();
}

/// Error with a message that is safe to show to the user.
class UserFacingException implements Exception {
  const UserFacingException(this.message);
  final String message;

  @override
  String toString() => message;
}
