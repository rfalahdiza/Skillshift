import '../core/utils/gaps.dart';
import '../core/utils/time.dart';

class Course {
  const Course({required this.id, required this.code, required this.name});

  factory Course.fromRow(Map<String, dynamic> r) => Course(
    id: r['id'] as String,
    code: r['code'] as String? ?? '',
    name: r['name'] as String,
  );

  final String id;
  final String code;
  final String name;
}

enum LearningStyle {
  workedExamples('worked_examples', 'Worked examples, step by step'),
  conceptFirst('concept_first', 'Talk through the concept first'),
  practiceTogether('practice_together', 'Practice questions together');

  const LearningStyle(this.db, this.label);
  final String db;
  final String label;

  static LearningStyle? tryParse(String? v) =>
      values.where((s) => s.db == v).firstOrNull;
}

class TimetableEntry {
  const TimetableEntry({
    required this.id,
    required this.dayOfWeek,
    required this.start,
    required this.end,
    required this.courseName,
    this.room,
  });

  factory TimetableEntry.fromRow(Map<String, dynamic> r) => TimetableEntry(
    id: r['id'] as String,
    dayOfWeek: (r['day_of_week'] as num).toInt(),
    start: parseHm(r['start_time'] as String),
    end: parseHm(r['end_time'] as String),
    courseName: r['course_name'] as String,
    room: r['room'] as String?,
  );

  final String id;

  /// ISO weekday, 1 = Monday.
  final int dayOfWeek;

  /// Minutes since midnight.
  final int start;
  final int end;
  final String courseName;
  final String? room;

  TimeRange get range => TimeRange(start, end);
}

/// A new class the user is adding (no id yet).
class TimetableDraft {
  const TimetableDraft({
    required this.dayOfWeek,
    required this.start,
    required this.end,
    required this.courseName,
    this.room,
  });

  final int dayOfWeek;
  final int start;
  final int end;
  final String courseName;
  final String? room;

  Map<String, dynamic> toRow(String userId) => {
    'user_id': userId,
    'day_of_week': dayOfWeek,
    'start_time': hm(start),
    'end_time': hm(end),
    'course_name': courseName,
    'room': room,
  };
}

class LearnerPreference {
  const LearnerPreference({
    required this.courseId,
    required this.style,
    this.openAnswer,
    this.aiTags = const [],
  });

  final String courseId;
  final LearningStyle style;
  final String? openAnswer;
  final List<String> aiTags;
}

/// A real instant range (UTC). Display with the WIB formatters.
class Slot {
  const Slot(this.startsAt, this.endsAt);

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
    DateTime.parse(j['starts_at'] as String).toUtc(),
    DateTime.parse(j['ends_at'] as String).toUtc(),
  );

  final DateTime startsAt;
  final DateTime endsAt;

  int get minutes => endsAt.difference(startsAt).inMinutes;

  String get label => fmtSlot(startsAt, endsAt);
}

class MentorMatch {
  const MentorMatch({
    required this.mentorId,
    required this.fullName,
    required this.program,
    required this.cohortYear,
    required this.proofType,
    required this.pricePerHour,
    required this.reason,
    required this.reasonFromAi,
    required this.slot,
    required this.sharedSlots,
    required this.freeTrialAvailable,
    this.gpa,
    this.bio,
    this.teachingTags = const [],
    this.coursesTaught = const [],
    this.freeTrialUsedOn,
  });

  factory MentorMatch.fromJson(Map<String, dynamic> j) => MentorMatch(
    mentorId: j['mentor_id'] as String,
    fullName: j['full_name'] as String? ?? 'Mentor',
    program: j['program'] as String? ?? '',
    cohortYear: (j['cohort_year'] as num?)?.toInt() ?? 0,
    proofType: j['proof_type'] as String? ?? 'grade_a',
    gpa: (j['gpa'] as num?)?.toDouble(),
    pricePerHour: (j['price_per_hour'] as num).toInt(),
    bio: j['bio'] as String?,
    teachingTags: (j['teaching_tags'] as List?)?.cast<String>() ?? const [],
    coursesTaught: (j['courses'] as List?)?.cast<String>() ?? const [],
    reason: j['reason'] as String? ?? '',
    reasonFromAi: j['reason_source'] == 'ai',
    slot: Slot.fromJson(j['slot'] as Map<String, dynamic>),
    sharedSlots: [
      for (final s in (j['shared_slots'] as List? ?? const []))
        Slot.fromJson(s as Map<String, dynamic>),
    ],
    freeTrialAvailable: j['free_trial_available'] as bool? ?? true,
    freeTrialUsedOn: j['free_trial_used_on'] == null
        ? null
        : DateTime.parse(j['free_trial_used_on'] as String),
  );

  final String mentorId;
  final String fullName;
  final String program;
  final int cohortYear;

  /// `grade_a` or `gpa`.
  final String proofType;
  final double? gpa;
  final int pricePerHour;
  final String? bio;
  final List<String> teachingTags;
  final List<String> coursesTaught;

  /// One line from Gemini, or the fallback sentence if it failed.
  final String reason;
  final bool reasonFromAi;

  /// Suggested slot (earliest shared gap).
  final Slot slot;

  /// Shared free gaps in the next 7 days (Mon–Fri, 07:00–17:00).
  final List<Slot> sharedSlots;
  final bool freeTrialAvailable;
  final DateTime? freeTrialUsedOn;

  String proofLabel(String courseName) => proofType == 'gpa' && gpa != null
      ? 'GPA ${gpa!.toStringAsFixed(2)}'
      : 'A in $courseName';
}

class MatchResult {
  const MatchResult({required this.course, required this.matches});

  final Course course;
  final List<MentorMatch> matches;
}

enum BookingStatus {
  requested('Requested'),
  accepted('Accepted'),
  declined('Declined'),
  completed('Completed'),
  cancelled('Cancelled');

  const BookingStatus(this.label);
  final String label;

  static BookingStatus parse(String v) =>
      values.firstWhere((s) => s.name == v, orElse: () => requested);
}

class Booking {
  const Booking({
    required this.id,
    required this.learnerId,
    required this.mentorId,
    required this.courseId,
    required this.courseName,
    required this.startsAt,
    required this.durationMin,
    required this.place,
    required this.isFreeTrial,
    required this.status,
    this.counterpartName,
    this.paymentStatus,
    this.gross,
  });

  final String id;
  final String learnerId;
  final String mentorId;
  final String courseId;
  final String courseName;
  final DateTime startsAt;
  final int durationMin;
  final String place;
  final bool isFreeTrial;
  final BookingStatus status;

  /// The other person's name (mentor for a learner, learner for a mentor).
  final String? counterpartName;
  final String? paymentStatus;
  final int? gross;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMin));

  bool get isUpcoming =>
      (status == BookingStatus.requested || status == BookingStatus.accepted) &&
      endsAt.isAfter(DateTime.now());
}

/// What the learner sends from L11.
class BookingRequest {
  const BookingRequest({
    required this.mentorId,
    required this.courseId,
    required this.startsAt,
    required this.durationMin,
    required this.place,
    required this.isFreeTrial,
  });

  final String mentorId;
  final String courseId;
  final DateTime startsAt;
  final int durationMin;
  final String place;
  final bool isFreeTrial;
}

/// Meeting spots offered on L11.
class CampusPlace {
  const CampusPlace(this.name, this.note);
  final String name;
  final String note;
}

const kCampusPlaces = [
  CampusPlace(
    'Gedung F, Lt. 2 study area',
    'FILKOM · near most first-year classes',
  ),
  CampusPlace('Perpustakaan UB, Lt. 3', 'Quiet zone'),
  CampusPlace('Gedung G, Lt. 1 lounge', 'FILKOM · open seating'),
];

// ---------------------------------------------------------------------------
// Phase 3: payments (Midtrans SANDBOX) and attendance
// ---------------------------------------------------------------------------

enum PaymentMethod {
  qris('qris', 'QRIS', 'GoPay, OVO, DANA, ShopeePay, m-banking'),
  va('va', 'Virtual account', 'BCA, BNI, BRI, Mandiri');

  const PaymentMethod(this.db, this.label, this.subtitle);
  final String db;
  final String label;
  final String subtitle;
}

/// Result of L12 "Pay": the booking and the Snap page to pay on.
class PaymentStart {
  const PaymentStart({
    required this.bookingId,
    required this.gross,
    required this.redirectUrl,
    required this.expiresAt,
  });

  final String bookingId;
  final int gross;

  /// Midtrans Snap SANDBOX page (QRIS / VA instructions).
  final String redirectUrl;
  final DateTime expiresAt;
}

/// pending | held | released | refunded | expired | failed
class PaymentState {
  const PaymentState({
    required this.paymentStatus,
    required this.bookingStatus,
  });

  final String? paymentStatus;
  final BookingStatus bookingStatus;

  bool get isPaid => paymentStatus == 'held' || paymentStatus == 'released';
  bool get isDead => paymentStatus == 'expired' || paymentStatus == 'failed';
}

class SessionPayment {
  const SessionPayment({
    required this.status,
    required this.gross,
    required this.platformFee,
    required this.mentorNet,
    this.redirectUrl,
    this.expiresAt,
  });

  final String status;
  final int gross;
  final int platformFee;
  final int mentorNet;
  final String? redirectUrl;
  final DateTime? expiresAt;
}

/// Everything L14 and L15 show for one booking.
class SessionDetail {
  const SessionDetail({
    required this.booking,
    required this.myUserId,
    required this.learnerName,
    required this.mentorName,
    required this.confirmedAt,
    this.payment,
  });

  final Booking booking;
  final String myUserId;
  final String learnerName;
  final String mentorName;

  /// userId → when they confirmed attendance.
  final Map<String, DateTime> confirmedAt;
  final SessionPayment? payment;

  bool get iAmLearner => booking.learnerId == myUserId;
  String get otherName => iAmLearner ? mentorName : learnerName;
  String get otherId => iAmLearner ? booking.mentorId : booking.learnerId;
  bool get iConfirmed => confirmedAt.containsKey(myUserId);
  bool get otherConfirmed => confirmedAt.containsKey(otherId);
  bool get hasStarted => !DateTime.now().isBefore(booking.startsAt);

  /// Attendance can be confirmed once an accepted session has started.
  bool get canConfirm =>
      hasStarted &&
      !iConfirmed &&
      (booking.status == BookingStatus.accepted ||
          booking.status == BookingStatus.completed);

  bool get canCancel =>
      !hasStarted &&
      (booking.status == BookingStatus.requested ||
          booking.status == BookingStatus.accepted);
}

// ---------------------------------------------------------------------------
// Phase 4: mentor
// ---------------------------------------------------------------------------

enum ApplicationStatus {
  pending,
  approved,
  rejected;

  static ApplicationStatus parse(String v) =>
      values.firstWhere((s) => s.name == v, orElse: () => pending);
}

class MentorApplication {
  const MentorApplication({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.proofType,
    required this.pricePerHour,
    required this.status,
    required this.createdAt,
    this.gpa,
    this.rejectReason,
  });

  final String id;
  final String courseId;
  final String courseName;

  /// `grade_a` or `gpa`.
  final String proofType;
  final double? gpa;
  final int pricePerHour;
  final ApplicationStatus status;
  final DateTime createdAt;
  final String? rejectReason;
}

class MentorCourse {
  const MentorCourse({
    required this.courseId,
    required this.courseName,
    required this.pricePerHour,
  });

  final String courseId;
  final String courseName;
  final int pricePerHour;
}

/// Where a mentor stands: verified courses and applications.
class MentorOverview {
  const MentorOverview({required this.courses, required this.applications});

  final List<MentorCourse> courses;
  final List<MentorApplication> applications;

  bool get isVerified => courses.isNotEmpty;
  MentorApplication? get latestPending => applications
      .where((a) => a.status == ApplicationStatus.pending)
      .firstOrNull;
  MentorApplication? get latestRejected => applications
      .where((a) => a.status == ApplicationStatus.rejected)
      .firstOrNull;
}

/// What M02 submits.
class ApplicationDraft {
  const ApplicationDraft({
    required this.courseId,
    required this.khsPath,
    required this.proofType,
    required this.pricePerHour,
    this.gpa,
  });

  final String courseId;
  final String khsPath;
  final String proofType;
  final double? gpa;
  final int pricePerHour;
}

/// A booking seen by the mentor, with what the learner asked for.
class MentorBooking {
  const MentorBooking({required this.booking, this.learnerTags = const []});

  final Booking booking;

  /// From the learner's quiz for this course (AI tags).
  final List<String> learnerTags;

  /// Paid requests only show once the payment is held.
  bool get isActionableRequest =>
      booking.status == BookingStatus.requested &&
      (booking.isFreeTrial || booking.paymentStatus == 'held');

  String get wantsLine {
    final words = learnerTags
        .map((t) => t.replaceAll('_', ' '))
        .where((t) => t.isNotEmpty)
        .take(4)
        .toList();
    if (words.isEmpty) return 'No preferences shared yet.';
    return 'Wants: ${words.join(', ')}.';
  }
}

/// One row on M05.
class EarningLine {
  const EarningLine({
    required this.bookingId,
    required this.learnerName,
    required this.courseName,
    required this.startsAt,
    required this.gross,
    required this.fee,
    required this.net,
    required this.status,
  });

  final String bookingId;
  final String learnerName;
  final String courseName;
  final DateTime startsAt;
  final int gross;
  final int fee;
  final int net;

  /// `held` (on hold) or `released` (simulated payout).
  final String status;
}

class Earnings {
  const Earnings({required this.lines, required this.feePercent});

  final List<EarningLine> lines;
  final num feePercent;

  int get available =>
      lines.where((l) => l.status == 'released').fold(0, (s, l) => s + l.net);
  int get onHold =>
      lines.where((l) => l.status == 'held').fold(0, (s, l) => s + l.net);

  /// Released this calendar month (WIB is close enough for a summary).
  int get thisMonth {
    final now = DateTime.now();
    return lines
        .where(
          (l) =>
              l.status == 'released' &&
              l.startsAt.year == now.year &&
              l.startsAt.month == now.month,
        )
        .fold(0, (s, l) => s + l.net);
  }

  int get paidSessionsThisMonth {
    final now = DateTime.now();
    return lines
        .where(
          (l) =>
              l.status == 'released' &&
              l.startsAt.year == now.year &&
              l.startsAt.month == now.month,
        )
        .length;
  }
}
