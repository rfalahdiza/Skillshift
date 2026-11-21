import '../auth/app_session.dart';

abstract final class Routes {
  // Public
  static const splash = '/';
  static const onboarding = '/welcome';
  static const signIn = '/sign-in';
  static const verify = '/verify';

  // Signed in, no role yet
  static const chooseRole = '/choose-role';

  // Learner
  static const learnerHome = '/learner';
  static const learnerFind = '/learner/find';
  static const learnerTimetable = '/learner/timetable';
  static const learnerSessions = '/learner/sessions';
  static const learnerProfile = '/learner/profile';
  // Full-screen learner flows (above the shell)
  static const learnerSetupTimetable = '/learner/setup/timetable'; // L06
  static const learnerQuiz = '/learner/quiz'; // L07
  static const learnerSetupQuiz = '/learner/setup/quiz'; // L07 in onboarding
  static String learnerMentor(String id) => '/learner/mentor/$id'; // L10
  static String learnerBook(String id) => '/learner/book/$id'; // L11
  static const learnerCheckout = '/learner/checkout'; // L12
  static String learnerPay(String bookingId) =>
      '/learner/pay/$bookingId'; // L13
  static String learnerBooked(String bookingId) =>
      '/learner/booked/$bookingId'; // L14
  static String learnerSession(String bookingId) =>
      '/learner/session/$bookingId'; // L15

  // Mentor
  static const mentorHome = '/mentor';
  static const mentorSessions = '/mentor/sessions';
  static const mentorEarnings = '/mentor/earnings';
  static const mentorProfile = '/mentor/profile';
  static const mentorApply = '/mentor/apply'; // M01
  static const mentorApplyPrice = '/mentor/apply/price'; // M02
  static const mentorPending = '/mentor/pending'; // M03
  static String mentorSession(String bookingId) => '/mentor/session/$bookingId';

  // Admin
  static const adminDashboard = '/admin';
  static const adminApplications = '/admin/applications';
  static const adminMentors = '/admin/mentors';
  static const adminSessions = '/admin/sessions';
  static const adminPayments = '/admin/payments';
  static const adminSettings = '/admin/settings';
  static String adminReview(String applicationId) =>
      '/admin/applications/$applicationId'; // AD03 / A03

  // Debug only
  static const devComponents = '/dev/components';

  static const publicPaths = {splash, onboarding, signIn, verify};

  static String homeFor(UserRole role) => switch (role) {
    UserRole.learner => learnerHome,
    UserRole.mentor => mentorHome,
    UserRole.admin => adminDashboard,
  };

  static String prefixFor(UserRole role) => '/${role.name}';
}
