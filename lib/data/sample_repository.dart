import 'dart:async';

import '../core/utils/time.dart';
import 'models.dart';
import 'repository.dart';

/// Offline FAKE data for the debug-only "Dev preview". Mirrors the seed and
/// the Figma frames (Nadia Putri, Raka Pratama, ...). Never used in release.
class SampleRepository implements SkillShiftRepository {
  SampleRepository() {
    _timetable.addAll(_nadiaTimetable());
    _bookings.addAll(_seedBookings());
    // Paid sample sessions: payment held by the platform (sandbox).
    for (final b in _bookings.where((b) => !b.isFreeTrial)) {
      _payments[b.id] = const SessionPayment(
        status: 'held',
        gross: 25000,
        platformFee: 2500,
        mentorNet: 22500,
      );
    }
  }

  static const _raka = 'b0000000-0000-4000-8000-000000000001';
  final _payments = <String, SessionPayment>{};
  final _attendance = <String, Map<String, DateTime>>{};

  static const _latency = Duration(milliseconds: 350);
  static const learnerId = 'preview-learner';

  static const kalkulus = Course(
    id: 'e0000000-0000-4000-8000-000000000001',
    code: 'MAT61001',
    name: 'Kalkulus 1',
  );
  static const _courses = [
    kalkulus,
    Course(
      id: 'e0000000-0000-4000-8000-000000000002',
      code: 'CIF61002',
      name: 'Pemrograman Dasar',
    ),
    Course(
      id: 'e0000000-0000-4000-8000-000000000003',
      code: 'CIF61003',
      name: 'Matematika Komputasi',
    ),
    Course(
      id: 'e0000000-0000-4000-8000-000000000004',
      code: 'FIS61001',
      name: 'Fisika Dasar',
    ),
    Course(
      id: 'e0000000-0000-4000-8000-000000000005',
      code: 'CIF62005',
      name: 'Struktur Data',
    ),
    Course(
      id: 'e0000000-0000-4000-8000-000000000006',
      code: 'CIF62006',
      name: 'Basis Data',
    ),
  ];

  final _timetable = <TimetableEntry>[];
  final _prefs = <String, LearnerPreference>{};
  final _bookings = <Booking>[];
  var _nextId = 1;

  Future<T> _delay<T>(T value) => Future.delayed(_latency, () => value);

  /// Next date (WIB, after today) that falls on [isoWeekday], at [hhmm].
  static DateTime nextWeekday(
    int isoWeekday,
    String hhmm, {
    int weeksAhead = 0,
  }) {
    final today = Wib.dateOnly(Wib.now());
    var d = today.add(const Duration(days: 1));
    while (d.weekday != isoWeekday) {
      d = d.add(const Duration(days: 1));
    }
    d = d.add(Duration(days: 7 * weeksAhead));
    final m = parseHm(hhmm);
    return Wib.fromWall(d.add(Duration(minutes: m)));
  }

  static Slot _slot(int weekday, String from, String to) =>
      Slot(nextWeekday(weekday, from), nextWeekday(weekday, to));

  List<TimetableEntry> _nadiaTimetable() {
    TimetableEntry e(int d, String s, String en, String c, String r) =>
        TimetableEntry(
          id: 'tt-${_nextId++}',
          dayOfWeek: d,
          start: parseHm(s),
          end: parseHm(en),
          courseName: c,
          room: r,
        );
    return [
      e(1, '07:00', '09:30', 'Fisika Dasar', 'Gedung F 3.4'),
      e(1, '10:20', '12:00', 'Bahasa Inggris', 'Gedung G 1.2'),
      e(1, '13:00', '14:40', 'Pengantar TI', 'Gedung F 2.1'),
      e(2, '07:00', '09:30', 'Kalkulus 1', 'Gedung F 2.3'),
      e(2, '10:20', '12:00', 'Pemrograman Dasar', 'Gedung G Lab 1'),
      e(2, '13:00', '15:30', 'Matematika Komputasi', 'Gedung F 2.5'),
      e(3, '08:40', '11:10', 'Pemrograman Dasar (Praktikum)', 'Lab 2'),
      e(3, '13:00', '14:40', 'Pendidikan Pancasila', 'Gedung A 1.3'),
      e(4, '07:00', '09:30', 'Kalkulus 1', 'Gedung F 2.3'),
      e(4, '10:20', '12:50', 'Matematika Komputasi', 'Gedung F 2.5'),
      e(5, '07:00', '08:40', 'Bahasa Indonesia', 'Gedung A 2.1'),
      e(5, '09:30', '11:10', 'Pengantar TI', 'Gedung F 2.1'),
    ];
  }

  List<Booking> _seedBookings() => [
    // Paid session that started 30 min ago: ready for "Confirm attendance".
    Booking(
      id: 'bk-now',
      learnerId: learnerId,
      mentorId: _raka,
      courseId: kalkulus.id,
      courseName: kalkulus.name,
      startsAt: DateTime.now().toUtc().subtract(const Duration(minutes: 30)),
      durationMin: 60,
      place: 'Gedung F, Lt. 2 study area',
      isFreeTrial: false,
      status: BookingStatus.accepted,
      counterpartName: 'Raka Pratama',
      paymentStatus: 'held',
      gross: 25000,
    ),
    // Upcoming paid session with Raka (payment held, sandbox).
    Booking(
      id: 'bk-1',
      learnerId: learnerId,
      mentorId: 'b0000000-0000-4000-8000-000000000001',
      courseId: kalkulus.id,
      courseName: kalkulus.name,
      startsAt: nextWeekday(2, '12:00'),
      durationMin: 60,
      place: 'Gedung F, Lt. 2 study area',
      isFreeTrial: false,
      status: BookingStatus.accepted,
      counterpartName: 'Raka Pratama',
      paymentStatus: 'held',
      gross: 25000,
    ),
    // Free trial with Raka last week (so his trial is used).
    Booking(
      id: 'bk-0',
      learnerId: learnerId,
      mentorId: 'b0000000-0000-4000-8000-000000000001',
      courseId: kalkulus.id,
      courseName: kalkulus.name,
      startsAt: nextWeekday(4, '09:30', weeksAhead: -1),
      durationMin: 30,
      place: 'Gedung F, Lt. 2 study area',
      isFreeTrial: true,
      status: BookingStatus.completed,
      counterpartName: 'Raka Pratama',
    ),
  ];

  @override
  Future<List<Course>> courses() => _delay(_courses);

  @override
  Future<Map<String, int>> mentorCounts() => _delay({
    _courses[0].id: 4,
    _courses[1].id: 6,
    _courses[2].id: 3,
    _courses[3].id: 2,
    _courses[4].id: 1,
    _courses[5].id: 1,
  });

  @override
  Future<List<TimetableEntry>> myTimetable() => _delay(List.of(_timetable));

  @override
  Future<TimetableEntry> addTimetableEntry(TimetableDraft d) {
    final entry = TimetableEntry(
      id: 'tt-${_nextId++}',
      dayOfWeek: d.dayOfWeek,
      start: d.start,
      end: d.end,
      courseName: d.courseName,
      room: d.room,
    );
    _timetable.add(entry);
    return _delay(entry);
  }

  @override
  Future<void> deleteTimetableEntry(String id) {
    _timetable.removeWhere((e) => e.id == id);
    return _delay(null);
  }

  @override
  Future<LearnerPreference?> preference(String courseId) =>
      _delay(_prefs[courseId]);

  @override
  Future<LearnerPreference> savePreference({
    required String courseId,
    required LearningStyle style,
    String? openAnswer,
  }) {
    final pref = LearnerPreference(
      courseId: courseId,
      style: style,
      openAnswer: openAnswer,
      aiTags: const ['limits', 'derivatives', 'patient'],
    );
    _prefs[courseId] = pref;
    return _delay(pref);
  }

  @override
  Future<MatchResult> findMatches(String courseId, {int? maxPrice}) {
    final course = _courses.firstWhere(
      (c) => c.id == courseId,
      orElse: () => kalkulus,
    );
    final trialUsedWithRaka = _bookings.any(
      (b) =>
          b.isFreeTrial &&
          b.mentorId == 'b0000000-0000-4000-8000-000000000001' &&
          b.status != BookingStatus.cancelled &&
          b.status != BookingStatus.declined,
    );
    final all = [
      MentorMatch(
        mentorId: 'b0000000-0000-4000-8000-000000000001',
        fullName: 'Raka Pratama',
        program: 'Informatika',
        cohortYear: 2024,
        proofType: 'grade_a',
        gpa: 3.78,
        pricePerHour: 25000,
        bio:
            'Second-year Informatika student. I like breaking calculus problems '
            'into small steps and checking each one together. Happy to meet in '
            'Gedung F or the library.',
        coursesTaught: const ['Kalkulus 1', 'Matematika Komputasi'],
        reason:
            'Free in your Tue 12:00 gap and teaches with worked examples, which '
            'you asked for.',
        reasonFromAi: true,
        slot: _slot(2, '12:00', '13:00'),
        sharedSlots: [
          _slot(2, '12:00', '13:00'),
          _slot(4, '09:30', '10:20'),
          _slot(5, '13:00', '17:00'),
        ],
        freeTrialAvailable: !trialUsedWithRaka,
        freeTrialUsedOn: trialUsedWithRaka
            ? _bookings.firstWhere((b) => b.isFreeTrial).startsAt
            : null,
      ),
      MentorMatch(
        mentorId: 'b0000000-0000-4000-8000-000000000002',
        fullName: 'Salsabila Hanum',
        program: 'Sistem Informasi',
        cohortYear: 2023,
        proofType: 'gpa',
        gpa: 3.85,
        pricePerHour: 30000,
        bio:
            'I explain the idea first, then we try problems. Calm and patient, '
            'good for anyone who feels lost.',
        coursesTaught: const ['Kalkulus 1', 'Basis Data'],
        reason: 'Patient, concept-first style. Shares your Thu 09:30 gap.',
        reasonFromAi: true,
        slot: _slot(4, '09:30', '10:20'),
        sharedSlots: [_slot(4, '09:30', '10:20'), _slot(2, '15:30', '17:00')],
        freeTrialAvailable: true,
      ),
      MentorMatch(
        mentorId: 'b0000000-0000-4000-8000-000000000003',
        fullName: 'Dimas Aditya',
        program: 'Teknik Komputer',
        cohortYear: 2024,
        proofType: 'grade_a',
        gpa: 3.52,
        pricePerHour: 20000,
        bio:
            'Practice-heavy sessions. We do many exam-style questions (never '
            'graded work) until it clicks.',
        coursesTaught: const ['Kalkulus 1', 'Fisika Dasar'],
        reason: 'Practice-heavy sessions on limits and derivatives.',
        reasonFromAi: false,
        slot: _slot(3, '11:10', '12:00'),
        sharedSlots: [_slot(3, '11:10', '12:00'), _slot(1, '09:30', '10:20')],
        freeTrialAvailable: true,
      ),
    ];
    final filtered = maxPrice == null
        ? all
        : all.where((m) => m.pricePerHour <= maxPrice).toList();
    return _delay(MatchResult(course: course, matches: filtered));
  }

  @override
  Future<List<Booking>> myBookings() => _delay(
    List.of(_bookings)..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
  );

  @override
  Future<Booking> requestBooking(BookingRequest q) {
    if (q.isFreeTrial &&
        _bookings.any(
          (b) =>
              b.isFreeTrial &&
              b.mentorId == q.mentorId &&
              b.status != BookingStatus.cancelled &&
              b.status != BookingStatus.declined,
        )) {
      return Future.error(
        const UserFacingException(
          'You already used your free trial with this mentor.',
        ),
      );
    }
    final names = {
      'b0000000-0000-4000-8000-000000000001': 'Raka Pratama',
      'b0000000-0000-4000-8000-000000000002': 'Salsabila Hanum',
      'b0000000-0000-4000-8000-000000000003': 'Dimas Aditya',
    };
    final booking = Booking(
      id: 'bk-${_nextId++}',
      learnerId: learnerId,
      mentorId: q.mentorId,
      courseId: q.courseId,
      courseName: _courses.firstWhere((c) => c.id == q.courseId).name,
      startsAt: q.startsAt,
      durationMin: q.durationMin,
      place: q.place,
      isFreeTrial: q.isFreeTrial,
      status: BookingStatus.requested,
      counterpartName: names[q.mentorId],
    );
    _bookings.add(booking);
    return _delay(booking);
  }

  // Phase 3 (preview only: payments are SIMULATED, nothing is charged) ------

  Booking _copy(Booking b, {BookingStatus? status, String? paymentStatus}) =>
      Booking(
        id: b.id,
        learnerId: b.learnerId,
        mentorId: b.mentorId,
        courseId: b.courseId,
        courseName: b.courseName,
        startsAt: b.startsAt,
        durationMin: b.durationMin,
        place: b.place,
        isFreeTrial: b.isFreeTrial,
        status: status ?? b.status,
        counterpartName: b.counterpartName,
        paymentStatus: paymentStatus ?? b.paymentStatus,
        gross: b.gross,
      );

  void _replace(Booking b) {
    final i = _bookings.indexWhere((x) => x.id == b.id);
    if (i >= 0) _bookings[i] = b;
  }

  @override
  Future<PaymentStart> startPaidBooking(
    BookingRequest q,
    PaymentMethod method,
  ) async {
    final booking = await requestBooking(q);
    const gross = 25000;
    _payments[booking.id] = SessionPayment(
      status: 'pending',
      gross: gross,
      platformFee: 2500,
      mentorNet: 22500,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
    );
    _replace(_copy(booking, paymentStatus: 'pending'));
    return PaymentStart(
      bookingId: booking.id,
      gross: gross,
      redirectUrl: 'about:blank',
      expiresAt: _payments[booking.id]!.expiresAt!,
    );
  }

  /// Preview: the first check "pays" instantly (simulated, no Midtrans).
  @override
  Future<PaymentState> checkPayment(String bookingId) {
    final p = _payments[bookingId];
    final b = _bookings.firstWhere((x) => x.id == bookingId);
    if (p != null && p.status == 'pending') {
      _payments[bookingId] = SessionPayment(
        status: 'held',
        gross: p.gross,
        platformFee: p.platformFee,
        mentorNet: p.mentorNet,
      );
      _replace(_copy(b, paymentStatus: 'held'));
    }
    return _delay(
      PaymentState(
        paymentStatus: _payments[bookingId]?.status,
        bookingStatus: b.status,
      ),
    );
  }

  @override
  Future<SessionDetail> sessionDetail(String bookingId) {
    final b = _bookings.firstWhere((x) => x.id == bookingId);
    return _delay(
      SessionDetail(
        booking: b,
        myUserId: learnerId,
        learnerName: 'Nadia Putri',
        mentorName: b.counterpartName ?? 'Mentor',
        confirmedAt: Map.of(_attendance[bookingId] ?? const {}),
        payment: _payments[bookingId],
      ),
    );
  }

  @override
  Future<void> confirmAttendance(String bookingId) {
    final b = _bookings.firstWhere((x) => x.id == bookingId);
    if (DateTime.now().isBefore(b.startsAt)) {
      return Future.error(
        const UserFacingException(
          'You can confirm attendance once the session has started',
        ),
      );
    }
    (_attendance[bookingId] ??= {})[learnerId] = DateTime.now().toUtc();
    return _delay(null);
  }

  @override
  Future<void> cancelBooking(String bookingId) {
    final b = _bookings.firstWhere((x) => x.id == bookingId);
    _replace(_copy(b, status: BookingStatus.cancelled));
    final p = _payments[bookingId];
    if (p != null && (p.status == 'held' || p.status == 'paid')) {
      _payments[bookingId] = SessionPayment(
        status: 'refunded',
        gross: p.gross,
        platformFee: p.platformFee,
        mentorNet: p.mentorNet,
      );
    }
    return _delay(null);
  }
}
