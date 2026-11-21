import '../../data/models.dart';
import '../../shared/widgets/mentor_match_card.dart';

MentorMatchData matchCardData(MentorMatch m, String courseName) =>
    MentorMatchData(
      mentorId: m.mentorId,
      name: m.fullName,
      program: m.program,
      cohortYear: m.cohortYear,
      proof: m.proofLabel(courseName),
      reason: m.reason,
      slotLabel: m.slot.label,
      pricePerHour: m.pricePerHour,
      firstSessionFree: m.freeTrialAvailable,
    );
