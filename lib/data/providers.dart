import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/app_session.dart';
import '../core/auth/session_controller.dart';
import '../core/supabase/supabase_providers.dart';
import 'models.dart';
import 'repository.dart';
import 'sample_repository.dart';
import 'supabase_repository.dart';

/// Real backend when signed in; offline fake data in the debug preview.
final repositoryProvider = Provider<SkillShiftRepository>((ref) {
  final preview = ref.watch(
    sessionProvider.select((s) => s.value?.isPreview ?? false),
  );
  final role = ref.watch(sessionProvider.select((s) => s.value?.role));
  final client = ref.watch(supabaseClientProvider);
  if (preview || client == null) {
    return SampleRepository(asMentor: role == UserRole.mentor);
  }
  return SupabaseRepository(client);
});

final coursesProvider = FutureProvider<List<Course>>(
  (ref) => ref.watch(repositoryProvider).courses(),
);

final mentorCountsProvider = FutureProvider<Map<String, int>>(
  (ref) => ref.watch(repositoryProvider).mentorCounts(),
);

final bookingsProvider = FutureProvider<List<Booking>>(
  (ref) => ref.watch(repositoryProvider).myBookings(),
);

/// The learner's classes, with add / delete.
final timetableProvider =
    AsyncNotifierProvider<TimetableController, List<TimetableEntry>>(
      TimetableController.new,
    );

class TimetableController extends AsyncNotifier<List<TimetableEntry>> {
  SkillShiftRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<List<TimetableEntry>> build() =>
      ref.watch(repositoryProvider).myTimetable();

  Future<void> add(TimetableDraft draft) async {
    final entry = await _repo.addTimetableEntry(draft);
    state = AsyncData([...state.value ?? const [], entry]);
  }

  Future<void> remove(String id) async {
    final before = state.value ?? const <TimetableEntry>[];
    state = AsyncData(before.where((e) => e.id != id).toList());
    try {
      await _repo.deleteTimetableEntry(id);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}

/// Course the learner is looking for help with (L07 → L09).
final selectedCourseProvider = NotifierProvider<SelectedCourse, String?>(
  SelectedCourse.new,
);

class SelectedCourse extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? courseId) => state = courseId;
}

/// "Under Rp30.000" filter on L09.
final priceCapProvider = NotifierProvider<PriceCap, int?>(PriceCap.new);

class PriceCap extends Notifier<int?> {
  @override
  int? build() => null;

  void toggle(int cap) => state = state == null ? cap : null;
}

final preferenceProvider = FutureProvider.family<LearnerPreference?, String>(
  (ref, courseId) => ref.watch(repositoryProvider).preference(courseId),
);

typedef MatchQuery = ({String courseId, int? maxPrice});

/// No automatic retry: every call runs up to 3 Gemini requests (free-tier
/// quota). On failure the screen shows "Try again" instead.
final matchesProvider = FutureProvider.family<MatchResult, MatchQuery>(
  (ref, q) => ref
      .watch(repositoryProvider)
      .findMatches(q.courseId, maxPrice: q.maxPrice),
  retry: (_, _) => null,
);

/// Finds a match already loaded for [mentorId] (L10/L11 reuse L09 data).
MentorMatch? cachedMatch(WidgetRef ref, String mentorId) {
  final courseId = ref.read(selectedCourseProvider);
  if (courseId == null) return null;
  final cap = ref.read(priceCapProvider);
  for (final q in <MatchQuery>[
    (courseId: courseId, maxPrice: cap),
    (courseId: courseId, maxPrice: null),
  ]) {
    final result = ref.read(matchesProvider(q)).value;
    final hit = result?.matches
        .where((m) => m.mentorId == mentorId)
        .firstOrNull;
    if (hit != null) return hit;
  }
  return null;
}

/// L14 / L15 detail for one booking. Refreshed after each action.
final sessionDetailProvider = FutureProvider.autoDispose
    .family<SessionDetail, String>(
      (ref, bookingId) =>
          ref.watch(repositoryProvider).sessionDetail(bookingId),
      retry: (_, _) => null,
    );

// Phase 4: mentor -----------------------------------------------------------

final mentorOverviewProvider = FutureProvider.autoDispose<MentorOverview>(
  (ref) => ref.watch(repositoryProvider).mentorOverview(),
  retry: (_, _) => null,
);

final mentorBookingsProvider = FutureProvider.autoDispose<List<MentorBooking>>(
  (ref) => ref.watch(repositoryProvider).mentorBookings(),
  retry: (_, _) => null,
);

final earningsProvider = FutureProvider.autoDispose<Earnings>(
  (ref) => ref.watch(repositoryProvider).earnings(),
  retry: (_, _) => null,
);
