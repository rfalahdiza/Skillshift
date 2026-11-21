import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'repository.dart';

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
}
