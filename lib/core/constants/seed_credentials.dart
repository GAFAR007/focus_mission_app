/**
 * WHAT:
 * seed_credentials stores the seeded demo accounts used for local development
 * and quick classroom-style testing.
 * WHY:
 * The app needs predictable sign-in data so role flows can be verified without
 * manually creating new users during development.
 * HOW:
 * Define typed demo account records and grouped helpers by role.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import '../../shared/models/user_role.dart';

class DemoAccount {
  const DemoAccount({
    required this.name,
    required this.email,
    required this.role,
    this.subject,
    this.isPlaceholder = false,
  });

  final String name;
  final String email;
  final UserRole role;
  final String? subject;
  final bool isPlaceholder;
}

abstract final class SeedCredentials {
  static const studentPassword = 'Password123!';
  static const staffPassword = 'flexiblelearning123!';

  static const studentEmail = 'student@focusmission.app';
  static const teacherEmail = 'ict.teacher@focusmission.app';
  static const mentorEmail = 'mentor@focusmission.app';
  static const managementEmail = 'aqsa.bi@flexiblelearning.org.uk';

  static const demoAccounts = <DemoAccount>[
    DemoAccount(name: 'Mohammed', email: studentEmail, role: UserRole.student),
    DemoAccount(
      name: 'John',
      email: 'john@focusmission.app',
      role: UserRole.student,
    ),
    DemoAccount(
      name: 'Mikolaj Radomski',
      email: 'sport.teacher@focusmission.app',
      role: UserRole.teacher,
      subject: 'Sport',
    ),
    DemoAccount(
      name: 'Mashrur Hossain',
      email: teacherEmail,
      role: UserRole.teacher,
      subject: 'ICT',
    ),
    DemoAccount(
      name: 'Tehreem Ali',
      email: 'business.teacher@focusmission.app',
      role: UserRole.teacher,
      subject: 'Business',
    ),
    DemoAccount(
      name: 'Ndumisa Nkomazana',
      email: 'science.teacher@focusmission.app',
      role: UserRole.teacher,
      subject: 'Science',
    ),
    DemoAccount(
      name: 'Health & Science Bot',
      email: 'healthscience.bot@focusmission.app',
      role: UserRole.teacher,
      subject: 'Health and Science',
      isPlaceholder: true,
    ),
    DemoAccount(
      name: 'RE Bot Teacher',
      email: 're.bot@focusmission.app',
      role: UserRole.teacher,
      subject: 'GCSE RE',
      isPlaceholder: true,
    ),
    DemoAccount(
      name: 'English Bot Teacher',
      email: 'english.bot@focusmission.app',
      role: UserRole.teacher,
      subject: 'English',
      isPlaceholder: true,
    ),
    DemoAccount(
      name: 'Maths Bot Teacher',
      email: 'maths.bot@focusmission.app',
      role: UserRole.teacher,
      subject: 'Mathematics',
      isPlaceholder: true,
    ),
    DemoAccount(
      name: 'Art Bot Teacher',
      email: 'art.bot@focusmission.app',
      role: UserRole.teacher,
      subject: 'Art',
      isPlaceholder: true,
    ),
    DemoAccount(
      name: 'Citizenship Bot Teacher',
      email: 'citizenship.bot@focusmission.app',
      role: UserRole.teacher,
      subject: 'GCSE Citizenship',
      isPlaceholder: true,
    ),
    DemoAccount(
      name: 'Gafar Temitayo Razak',
      email: mentorEmail,
      role: UserRole.mentor,
    ),
    DemoAccount(
      name: 'Aqsa Bi | SEN',
      email: managementEmail,
      role: UserRole.management,
    ),
  ];

  static List<DemoAccount> forRole(UserRole role) {
    return demoAccounts
        .where((account) => account.role == role)
        .toList(growable: false);
  }

  static String passwordForRole(UserRole role) {
    switch (role) {
      case UserRole.student:
        return studentPassword;
      case UserRole.teacher:
      case UserRole.mentor:
      case UserRole.management:
        return staffPassword;
    }
  }
}
