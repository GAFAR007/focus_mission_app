/**
 * WHAT:
 * school_access_session models the short-lived pre-login school access grant.
 * WHY:
 * The gate group must control which role screens and Quick Fill requests are
 * available without being confused with an authenticated user session.
 * HOW:
 * Parse the backend group/token/expiry response and expose the exact roles
 * permitted for student, staff, or management access.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'user_role.dart';

enum SchoolAccessGroup { student, staff, management }

class SchoolAccessSession {
  const SchoolAccessSession({
    required this.accessGroup,
    required this.gateToken,
    required this.expiresAt,
  });

  final SchoolAccessGroup accessGroup;
  final String gateToken;
  final DateTime expiresAt;

  factory SchoolAccessSession.fromJson(Map<String, dynamic> json) {
    final gateToken = (json['gateToken'] ?? '').toString().trim();
    final expiresAt = DateTime.tryParse(
      (json['expiresAt'] ?? '').toString(),
    )?.toUtc();
    if (gateToken.isEmpty || expiresAt == null) {
      throw const FormatException('Invalid school access response.');
    }

    return SchoolAccessSession(
      accessGroup: _parseAccessGroup(json['accessGroup']),
      gateToken: gateToken,
      expiresAt: expiresAt,
    );
  }

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  List<UserRole> get allowedRoles {
    switch (accessGroup) {
      case SchoolAccessGroup.student:
        return const [UserRole.student];
      case SchoolAccessGroup.staff:
        return const [UserRole.teacher, UserRole.mentor];
      case SchoolAccessGroup.management:
        return const [UserRole.management];
    }
  }
}

SchoolAccessGroup _parseAccessGroup(Object? value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'student':
      return SchoolAccessGroup.student;
    case 'staff':
      return SchoolAccessGroup.staff;
    case 'management':
      return SchoolAccessGroup.management;
    default:
      throw const FormatException('Unsupported school access group.');
  }
}
