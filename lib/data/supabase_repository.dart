import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'repository.dart';
import '../core/utils/formatters.dart';
import '../core/utils/time.dart';

class SupabaseRepository implements SkillShiftRepository {
  SupabaseRepository(this._db);

  final SupabaseClient _db;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const UserFacingException('Please sign in again.');
    return id;
  }

  /// Turns database / function errors into short, readable messages.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      // Our triggers raise readable messages with errcode P0001.
      if (e.code == 'P0001' || e.code == '23505') {
        throw UserFacingException(
          e.code == '23505'
              ? 'You already used your free trial with this mentor.'
              : e.message,
        );
      }
      throw const UserFacingException(
        'Something went wrong. Please try again.',
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final msg = details is Map ? details['error'] as String? : null;
      throw UserFacingException(
        msg ?? 'The server could not answer. Try again.',
      );
    } on AuthException catch (e) {
      throw UserFacingException(e.message);
    }
  }

  @override
  Future<List<Course>> courses() => _guard(() async {
    final rows = await _db
        .from('courses')
        .select('id, code, name')
        .order('name');
    return rows.map(Course.fromRow).toList();
  });

  @override
  Future<Map<String, int>> mentorCounts() => _guard(() async {
    final rows = await _db.from('mentor_courses').select('course_id');
    final counts = <String, int>{};
    for (final r in rows) {
      final id = r['course_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  });

  @override
  Future<List<TimetableEntry>> myTimetable() => _guard(() async {
    final rows = await _db
        .from('timetable_entries')
        .select()
        .eq('user_id', _uid)
        .order('day_of_week')
        .order('start_time');
    return rows.map(TimetableEntry.fromRow).toList();
  });

  @override
  Future<TimetableEntry> addTimetableEntry(TimetableDraft draft) =>
      _guard(() async {
        final row = await _db
            .from('timetable_entries')
            .insert(draft.toRow(_uid))
            .select()
            .single();
        return TimetableEntry.fromRow(row);
      });

  @override
  Future<void> deleteTimetableEntry(String id) =>
      _guard(() => _db.from('timetable_entries').delete().eq('id', id));

  @override
  Future<LearnerPreference?> preference(String courseId) => _guard(() async {
    final row = await _db
        .from('learner_preferences')
        .select()
        .eq('user_id', _uid)
        .eq('course_id', courseId)
        .maybeSingle();
    if (row == null) return null;
    return LearnerPreference(
      courseId: courseId,
      style:
          LearningStyle.tryParse(row['learning_style'] as String?) ??
          LearningStyle.workedExamples,
      openAnswer: row['open_answer'] as String?,
      aiTags: (row['ai_tags'] as List?)?.cast<String>() ?? const [],
    );
  });

  @override
  Future<LearnerPreference> savePreference({
    required String courseId,
    required LearningStyle style,
    String? openAnswer,
  }) => _guard(() async {
    final res = await _db.functions.invoke(
      'tag-preferences',
      body: {
        'course_id': courseId,
        'learning_style': style.db,
        'open_answer': openAnswer,
      },
    );
    final data = res.data as Map<String, dynamic>;
    return LearnerPreference(
      courseId: courseId,
      style: style,
      openAnswer: openAnswer,
      aiTags: (data['ai_tags'] as List?)?.cast<String>() ?? const [],
    );
  });

  @override
  Future<MatchResult> findMatches(String courseId, {int? maxPrice}) =>
      _guard(() async {
        final res = await _db.functions.invoke(
          'match-mentors',
          body: {'course_id': courseId, 'max_price': ?maxPrice},
        );
        final data = res.data as Map<String, dynamic>;
        return MatchResult(
          course: Course.fromRow(data['course'] as Map<String, dynamic>),
          matches: [
            for (final m in data['matches'] as List)
              MentorMatch.fromJson(m as Map<String, dynamic>),
          ],
        );
      });

  @override
  Future<List<Booking>> myBookings() => _guard(() async {
    final uid = _uid;
    final rows = await _db
        .from('bookings')
        .select('*, course:courses(name), payment:payments(status, gross)')
        .or('learner_id.eq.$uid,mentor_id.eq.$uid')
        .order('starts_at');

    final otherIds = {
      for (final r in rows)
        (r['learner_id'] == uid ? r['mentor_id'] : r['learner_id']) as String,
    };
    final names = <String, String>{};
    if (otherIds.isNotEmpty) {
      final people = await _db
          .from('profile_cards')
          .select('id, full_name')
          .inFilter('id', otherIds.toList());
      for (final p in people) {
        names[p['id'] as String] = p['full_name'] as String? ?? '';
      }
    }

    return [
      for (final r in rows)
        Booking(
          id: r['id'] as String,
          learnerId: r['learner_id'] as String,
          mentorId: r['mentor_id'] as String,
          courseId: r['course_id'] as String,
          courseName: (r['course'] as Map?)?['name'] as String? ?? '',
          startsAt: DateTime.parse(r['starts_at'] as String).toUtc(),
          durationMin: (r['duration_min'] as num).toInt(),
          place: r['place'] as String,
          isFreeTrial: r['is_free_trial'] as bool,
          status: BookingStatus.parse(r['status'] as String),
          counterpartName:
              names[r['learner_id'] == uid ? r['mentor_id'] : r['learner_id']],
          paymentStatus: (r['payment'] as Map?)?['status'] as String?,
          gross: ((r['payment'] as Map?)?['gross'] as num?)?.toInt(),
        ),
    ];
  });

  @override
  Future<Booking> requestBooking(BookingRequest q) => _guard(() async {
    final row = await _db
        .from('bookings')
        .insert({
          'learner_id': _uid,
          'mentor_id': q.mentorId,
          'course_id': q.courseId,
          'starts_at': q.startsAt.toUtc().toIso8601String(),
          'duration_min': q.durationMin,
          'place': q.place,
          'is_free_trial': q.isFreeTrial,
        })
        .select('*, course:courses(name)')
        .single();
    return Booking(
      id: row['id'] as String,
      learnerId: row['learner_id'] as String,
      mentorId: row['mentor_id'] as String,
      courseId: row['course_id'] as String,
      courseName: (row['course'] as Map?)?['name'] as String? ?? '',
      startsAt: DateTime.parse(row['starts_at'] as String).toUtc(),
      durationMin: (row['duration_min'] as num).toInt(),
      place: row['place'] as String,
      isFreeTrial: row['is_free_trial'] as bool,
      status: BookingStatus.parse(row['status'] as String),
    );
  });

  // Phase 3 -----------------------------------------------------------------

  @override
  Future<PaymentStart> startPaidBooking(
    BookingRequest q,
    PaymentMethod method,
  ) => _guard(() async {
    final res = await _db.functions.invoke(
      'create-payment',
      body: {
        'mentor_id': q.mentorId,
        'course_id': q.courseId,
        'starts_at': q.startsAt.toUtc().toIso8601String(),
        'place': q.place,
        'method': method.db,
      },
    );
    final d = res.data as Map<String, dynamic>;
    return PaymentStart(
      bookingId: d['booking_id'] as String,
      gross: (d['gross'] as num).toInt(),
      redirectUrl: d['redirect_url'] as String,
      expiresAt: DateTime.parse(d['expires_at'] as String).toUtc(),
    );
  });

  @override
  Future<PaymentState> checkPayment(String bookingId) => _guard(() async {
    final res = await _db.functions.invoke(
      'payment-status',
      body: {'booking_id': bookingId},
    );
    final d = res.data as Map<String, dynamic>;
    return PaymentState(
      paymentStatus: d['payment_status'] as String?,
      bookingStatus: BookingStatus.parse(
        d['booking_status'] as String? ?? 'requested',
      ),
    );
  });

  @override
  Future<SessionDetail> sessionDetail(String bookingId) => _guard(() async {
    final uid = _uid;
    final r = await _db
        .from('bookings')
        .select(
          '*, course:courses(name), '
          'payment:payments(status, gross, platform_fee, mentor_net, '
          'snap_redirect_url, expires_at), '
          'attendance(user_id, confirmed_at)',
        )
        .eq('id', bookingId)
        .single();
    final people = await _db
        .from('profile_cards')
        .select('id, full_name')
        .inFilter('id', [r['learner_id'], r['mentor_id']]);
    String nameOf(Object? id) =>
        people.where((p) => p['id'] == id).firstOrNull?['full_name']
            as String? ??
        '';
    final pay = r['payment'] as Map<String, dynamic>?;
    final booking = Booking(
      id: r['id'] as String,
      learnerId: r['learner_id'] as String,
      mentorId: r['mentor_id'] as String,
      courseId: r['course_id'] as String,
      courseName: (r['course'] as Map?)?['name'] as String? ?? '',
      startsAt: DateTime.parse(r['starts_at'] as String).toUtc(),
      durationMin: (r['duration_min'] as num).toInt(),
      place: r['place'] as String,
      isFreeTrial: r['is_free_trial'] as bool,
      status: BookingStatus.parse(r['status'] as String),
      counterpartName: nameOf(
        r['learner_id'] == uid ? r['mentor_id'] : r['learner_id'],
      ),
      paymentStatus: pay?['status'] as String?,
      gross: (pay?['gross'] as num?)?.toInt(),
    );
    return SessionDetail(
      booking: booking,
      myUserId: uid,
      learnerName: nameOf(r['learner_id']),
      mentorName: nameOf(r['mentor_id']),
      confirmedAt: {
        for (final a in (r['attendance'] as List? ?? const []))
          (a as Map)['user_id'] as String: DateTime.parse(
            a['confirmed_at'] as String,
          ).toUtc(),
      },
      payment: pay == null
          ? null
          : SessionPayment(
              status: pay['status'] as String,
              gross: (pay['gross'] as num).toInt(),
              platformFee: (pay['platform_fee'] as num).toInt(),
              mentorNet: (pay['mentor_net'] as num).toInt(),
              redirectUrl: pay['snap_redirect_url'] as String?,
              expiresAt: pay['expires_at'] == null
                  ? null
                  : DateTime.parse(pay['expires_at'] as String).toUtc(),
            ),
    );
  });

  @override
  Future<void> confirmAttendance(String bookingId) => _guard(
    () => _db.rpc('confirm_attendance', params: {'p_booking_id': bookingId}),
  );

  @override
  Future<void> cancelBooking(String bookingId) => _guard(
    () => _db.rpc('cancel_booking', params: {'p_booking_id': bookingId}),
  );

  // Phase 4: mentor ---------------------------------------------------------

  @override
  Future<MentorOverview> mentorOverview() => _guard(() async {
    final uid = _uid;
    final courses = await _db
        .from('mentor_courses')
        .select('course_id, price_per_hour, course:courses(name)')
        .eq('mentor_id', uid);
    final apps = await _db
        .from('mentor_applications')
        .select(
          'id, course_id, proof_type, gpa, price_per_hour, status, '
          'created_at, reject_reason, course:courses(name)',
        )
        .eq('mentor_id', uid)
        .order('created_at', ascending: false);
    return MentorOverview(
      courses: [
        for (final c in courses)
          MentorCourse(
            courseId: c['course_id'] as String,
            courseName: (c['course'] as Map?)?['name'] as String? ?? '',
            pricePerHour: (c['price_per_hour'] as num).toInt(),
          ),
      ],
      applications: [
        for (final a in apps)
          MentorApplication(
            id: a['id'] as String,
            courseId: a['course_id'] as String,
            courseName: (a['course'] as Map?)?['name'] as String? ?? '',
            proofType: a['proof_type'] as String,
            gpa: (a['gpa'] as num?)?.toDouble(),
            pricePerHour: (a['price_per_hour'] as num).toInt(),
            status: ApplicationStatus.parse(a['status'] as String),
            createdAt: DateTime.parse(a['created_at'] as String).toUtc(),
            rejectReason: a['reject_reason'] as String?,
          ),
      ],
    );
  });

  @override
  Future<({int min, int max})> priceRange(String courseId) => _guard(() async {
    final rows =
        await _db.rpc('price_range', params: {'p_course_id': courseId}) as List;
    final r = rows.first as Map<String, dynamic>;
    return (
      min: (r['price_min'] as num).toInt(),
      max: (r['price_max'] as num).toInt(),
    );
  });

  @override
  Future<String> uploadKhs(List<int> bytes, String fileName) =>
      _guard(() async {
        final lower = fileName.toLowerCase();
        final type = lower.endsWith('.pdf')
            ? 'application/pdf'
            : lower.endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        final safe = lower.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
        final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}_$safe';
        await _db.storage
            .from('khs')
            .uploadBinary(
              path,
              Uint8List.fromList(bytes),
              fileOptions: FileOptions(contentType: type, upsert: false),
            );
        return path;
      });

  @override
  Future<void> submitApplication(ApplicationDraft d) => _guard(
    () => _db.from('mentor_applications').insert({
      'mentor_id': _uid,
      'course_id': d.courseId,
      'khs_path': d.khsPath,
      'proof_type': d.proofType,
      'gpa': d.gpa,
      'price_per_hour': d.pricePerHour,
      'agreed_no_graded_work': true,
    }),
  );

  @override
  Future<List<MentorBooking>> mentorBookings() => _guard(() async {
    final uid = _uid;
    final mine = (await myBookings()).where((b) => b.mentorId == uid).toList();
    final learnerIds = {for (final b in mine) b.learnerId}.toList();
    final tags = <String, List<String>>{};
    if (learnerIds.isNotEmpty) {
      final prefs = await _db
          .from('learner_preferences')
          .select('user_id, course_id, ai_tags')
          .inFilter('user_id', learnerIds);
      for (final p in prefs) {
        tags['${p['user_id']}|${p['course_id']}'] =
            (p['ai_tags'] as List?)?.cast<String>() ?? const [];
      }
    }
    return [
      for (final b in mine)
        MentorBooking(
          booking: b,
          learnerTags: tags['${b.learnerId}|${b.courseId}'] ?? const [],
        ),
    ];
  });

  @override
  Future<void> respondToBooking(String bookingId, {required bool accept}) =>
      _guard(
        () => _db.rpc(
          'respond_to_booking',
          params: {'p_booking_id': bookingId, 'p_accept': accept},
        ),
      );

  @override
  Future<Earnings> earnings() => _guard(() async {
    final uid = _uid;
    final rows = await _db
        .from('payments')
        .select(
          'gross, platform_fee, mentor_net, status, '
          'booking:bookings!inner(id, starts_at, learner_id, mentor_id, '
          'course:courses(name))',
        )
        .eq('booking.mentor_id', uid)
        .inFilter('status', ['held', 'released']);
    final learnerIds = {
      for (final r in rows) (r['booking'] as Map)['learner_id'] as String,
    }.toList();
    final names = <String, String>{};
    if (learnerIds.isNotEmpty) {
      final people = await _db
          .from('profile_cards')
          .select('id, full_name')
          .inFilter('id', learnerIds);
      for (final p in people) {
        names[p['id'] as String] = p['full_name'] as String? ?? '';
      }
    }
    final cfg = await _db
        .from('app_config')
        .select('platform_fee_percent')
        .single();
    final lines = [
      for (final r in rows)
        EarningLine(
          bookingId: (r['booking'] as Map)['id'] as String,
          learnerName: names[(r['booking'] as Map)['learner_id']] ?? '',
          courseName:
              ((r['booking'] as Map)['course'] as Map?)?['name'] as String? ??
              '',
          startsAt: DateTime.parse((r['booking'] as Map)['starts_at'] as String)
              .toUtc(),
          gross: (r['gross'] as num).toInt(),
          fee: (r['platform_fee'] as num).toInt(),
          net: (r['mentor_net'] as num).toInt(),
          status: r['status'] as String,
        ),
    ]..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return Earnings(
      lines: lines,
      feePercent: cfg['platform_fee_percent'] as num,
    );
  });

  // Phase 5: admin (RLS: is_admin() can read all rows) ----------------------

  static const _mentorJoin =
      'mentor:profiles!mentor_applications_mentor_id_fkey'
      '(full_name, email, nim, program, cohort_year, is_test_data)';
  static const _bookingPeople =
      'learner:profiles!bookings_learner_id_fkey(full_name), '
      'mentor:profiles!bookings_mentor_id_fkey(full_name)';

  @override
  Future<AdminStats> adminStats() => _guard(() async {
    final pending = await _db
        .from('mentor_applications')
        .select('created_at')
        .eq('status', 'pending')
        .order('created_at');
    final mentors = await _db.from('mentor_courses').select('mentor_id');
    final now = Wib.now();
    final monday = Wib.dateOnly(now).subtract(Duration(days: now.weekday - 1));
    final from = Wib.fromWall(monday);
    final to = from.add(const Duration(days: 7));
    final sessions = await _db
        .from('bookings')
        .select('id')
        .gte('starts_at', from.toIso8601String())
        .lt('starts_at', to.toIso8601String())
        .inFilter('status', ['requested', 'accepted', 'completed']);
    final held = await _db
        .from('payments')
        .select('gross')
        .eq('status', 'held');
    return AdminStats(
      pendingApplications: pending.length,
      verifiedMentors: {for (final m in mentors) m['mentor_id']}.length,
      sessionsThisWeek: sessions.length,
      onHoldAmount: held.fold<int>(
        0,
        (s, r) => s + (r['gross'] as num).toInt(),
      ),
      oldestPending: pending.isEmpty
          ? null
          : DateTime.parse(pending.first['created_at'] as String).toUtc(),
    );
  });

  @override
  Future<List<ActivityItem>> recentActivity() => _guard(() async {
    final pays = await _db
        .from('payments')
        .select(
          'status, gross, mentor_net, paid_at, released_at, '
          'booking:bookings($_bookingPeople)',
        )
        .not('paid_at', 'is', null)
        .order('paid_at', ascending: false)
        .limit(10);
    final apps = await _db
        .from('mentor_applications')
        .select(
          'status, created_at, reviewed_at, reject_reason, '
          'course:courses(name), $_mentorJoin',
        )
        .order('created_at', ascending: false)
        .limit(10);
    String first(Map? m) =>
        ((m?['full_name'] as String?) ?? '').split(' ').first;
    final items = <ActivityItem>[
      for (final p in pays) ...[
        ActivityItem(
          kind: ActivityKind.paid,
          title:
              '${first((p['booking'] as Map?)?['learner'] as Map?)} paid '
              '${formatRupiah((p['gross'] as num).toInt())}',
          subtitle:
              'Held for session with '
              '${first((p['booking'] as Map?)?['mentor'] as Map?)} · sandbox',
          at: DateTime.parse(p['paid_at'] as String).toUtc(),
        ),
        if (p['released_at'] != null)
          ActivityItem(
            kind: ActivityKind.released,
            title: 'Session confirmed by both',
            subtitle:
                '${formatRupiah((p['mentor_net'] as num).toInt())} released to '
                '${first((p['booking'] as Map?)?['mentor'] as Map?)} (simulated)',
            at: DateTime.parse(p['released_at'] as String).toUtc(),
          ),
      ],
      for (final a in apps) ...[
        ActivityItem(
          kind: ActivityKind.applied,
          title:
              'New application: '
              '${(a['mentor'] as Map?)?['full_name'] ?? ''}',
          subtitle: (a['course'] as Map?)?['name'] as String? ?? '',
          at: DateTime.parse(a['created_at'] as String).toUtc(),
        ),
        if (a['reviewed_at'] != null)
          ActivityItem(
            kind: a['status'] == 'rejected'
                ? ActivityKind.rejected
                : ActivityKind.approved,
            title: a['status'] == 'rejected'
                ? 'Application rejected'
                : 'Mentor approved',
            subtitle:
                '${first(a['mentor'] as Map?)} · '
                '${(a['course'] as Map?)?['name'] ?? ''}',
            at: DateTime.parse(a['reviewed_at'] as String).toUtc(),
          ),
      ],
    ]..sort((a, b) => b.at.compareTo(a.at));
    return items.take(6).toList();
  });

  @override
  Future<List<AdminApplication>> applications() => _guard(() async {
    final rows = await _db
        .from('mentor_applications')
        .select('*, course:courses(name), $_mentorJoin')
        .order('created_at', ascending: false);
    return [
      for (final a in rows)
        AdminApplication(
          application: MentorApplication(
            id: a['id'] as String,
            courseId: a['course_id'] as String,
            courseName: (a['course'] as Map?)?['name'] as String? ?? '',
            proofType: a['proof_type'] as String,
            gpa: (a['gpa'] as num?)?.toDouble(),
            pricePerHour: (a['price_per_hour'] as num).toInt(),
            status: ApplicationStatus.parse(a['status'] as String),
            createdAt: DateTime.parse(a['created_at'] as String).toUtc(),
            rejectReason: a['reject_reason'] as String?,
          ),
          mentorId: a['mentor_id'] as String,
          mentorName: (a['mentor'] as Map?)?['full_name'] as String? ?? '',
          mentorEmail: (a['mentor'] as Map?)?['email'] as String? ?? '',
          nim: (a['mentor'] as Map?)?['nim'] as String?,
          program: (a['mentor'] as Map?)?['program'] as String?,
          cohortYear: ((a['mentor'] as Map?)?['cohort_year'] as num?)?.toInt(),
          khsPath: a['khs_path'] as String?,
          isTestData: (a['mentor'] as Map?)?['is_test_data'] as bool? ?? false,
        ),
    ];
  });

  @override
  Future<String?> khsUrl(String path) async {
    try {
      // 5 minutes is enough to look at it; the link then stops working.
      return await _db.storage.from('khs').createSignedUrl(path, 300);
    } on StorageException {
      return null; // e.g. seeded sample applications have no file
    }
  }

  @override
  Future<void> reviewApplication(
    String applicationId, {
    required bool approve,
    String? reason,
  }) => _guard(
    () => _db.rpc(
      'review_application',
      params: {
        'p_application_id': applicationId,
        'p_approve': approve,
        'p_reason': reason,
      },
    ),
  );

  @override
  Future<List<AdminPayment>> adminPayments() => _guard(() async {
    final rows = await _db
        .from('payments')
        .select(
          'gross, platform_fee, mentor_net, status, method, created_at, '
          'booking:bookings(id, course:courses(name), $_bookingPeople)',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return [
      for (final r in rows)
        AdminPayment(
          bookingId: (r['booking'] as Map?)?['id'] as String? ?? '',
          learnerName:
              ((r['booking'] as Map?)?['learner'] as Map?)?['full_name']
                  as String? ??
              '',
          mentorName:
              ((r['booking'] as Map?)?['mentor'] as Map?)?['full_name']
                  as String? ??
              '',
          courseName:
              ((r['booking'] as Map?)?['course'] as Map?)?['name'] as String? ??
              '',
          gross: (r['gross'] as num).toInt(),
          fee: (r['platform_fee'] as num).toInt(),
          net: (r['mentor_net'] as num).toInt(),
          status: r['status'] as String,
          method: r['method'] as String?,
          createdAt: DateTime.parse(r['created_at'] as String).toUtc(),
        ),
    ];
  });

  @override
  Future<List<Booking>> adminBookings() => _guard(() async {
    final rows = await _db
        .from('bookings')
        .select(
          '*, course:courses(name), payment:payments(status, gross), '
          '$_bookingPeople',
        )
        .order('starts_at', ascending: false)
        .limit(100);
    return [
      for (final r in rows)
        Booking(
          id: r['id'] as String,
          learnerId: r['learner_id'] as String,
          mentorId: r['mentor_id'] as String,
          courseId: r['course_id'] as String,
          courseName: (r['course'] as Map?)?['name'] as String? ?? '',
          startsAt: DateTime.parse(r['starts_at'] as String).toUtc(),
          durationMin: (r['duration_min'] as num).toInt(),
          place: r['place'] as String,
          isFreeTrial: r['is_free_trial'] as bool,
          status: BookingStatus.parse(r['status'] as String),
          counterpartName:
              '${(r['learner'] as Map?)?['full_name'] ?? ''} with '
              '${(r['mentor'] as Map?)?['full_name'] ?? ''}',
          paymentStatus: (r['payment'] as Map?)?['status'] as String?,
          gross: ((r['payment'] as Map?)?['gross'] as num?)?.toInt(),
        ),
    ];
  });

  @override
  Future<AppConfigView> appConfig() => _guard(() async {
    final c = await _db.from('app_config').select().single();
    return AppConfigView(
      platformFeePercent: c['platform_fee_percent'] as num,
      priceMin: (c['default_price_min'] as num).toInt(),
      priceMax: (c['default_price_max'] as num).toInt(),
      freeTrialMinutes: (c['free_trial_minutes'] as num).toInt(),
      minGpa: (c['min_gpa'] as num).toDouble(),
      allowedDomains: (c['allowed_email_domains'] as List).cast<String>(),
    );
  });

  // Phase 6: profile ----------------------------------------------------------

  @override
  Future<MyProfile> myProfile() => _guard(() async {
    final r = await _db
        .from('profiles')
        .select(
          'full_name, email, nim, program, cohort_year, bio, teaching_tags',
        )
        .eq('id', _uid)
        .single();
    return MyProfile(
      fullName: r['full_name'] as String? ?? '',
      email: r['email'] as String? ?? '',
      nim: r['nim'] as String?,
      program: r['program'] as String?,
      cohortYear: (r['cohort_year'] as num?)?.toInt(),
      bio: r['bio'] as String?,
      teachingTags: (r['teaching_tags'] as List?)?.cast<String>() ?? const [],
    );
  });

  @override
  Future<void> updateTeaching({
    required String bio,
    required List<String> tags,
  }) => _guard(
    () => _db
        .from('profiles')
        .update({
          'bio': bio.trim().isEmpty ? null : bio.trim(),
          'teaching_tags': tags,
        })
        .eq('id', _uid),
  );
}
