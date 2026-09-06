/**
 * WHAT:
 * seed_credentials defines the safe client model for backend Quick Fill
 * account responses.
 * WHY:
 * Names and email addresses must not be bundled into public Flutter Web code;
 * the school-gated backend is the only source of account-directory data.
 * HOW:
 * Parse the limited account fields returned after a valid gate token.
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

  factory DemoAccount.fromJson(Map<String, dynamic> json) {
    final subject = (json['subject'] ?? '').toString().trim();
    return DemoAccount(
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: _parseUserRole(json['role']),
      subject: subject.isEmpty ? null : subject,
      isPlaceholder: json['isPlaceholder'] == true,
    );
  }
}

UserRole _parseUserRole(Object? value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'student':
      return UserRole.student;
    case 'teacher':
      return UserRole.teacher;
    case 'mentor':
      return UserRole.mentor;
    case 'management':
      return UserRole.management;
    default:
      return UserRole.student;
  }
}
