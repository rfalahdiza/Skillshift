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

  // Mentor
  static const mentorHome = '/mentor';
  static const mentorSessions = '/mentor/sessions';
  static const mentorEarnings = '/mentor/earnings';
  static const mentorProfile = '/mentor/profile';

  // Admin
  static const adminDashboard = '/admin';
  static const adminApplications = '/admin/applications';
  static const adminMentors = '/admin/mentors';
  static const adminSessions = '/admin/sessions';
  static const adminPayments = '/admin/payments';
  static const adminSettings = '/admin/settings';

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
