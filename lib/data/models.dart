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
