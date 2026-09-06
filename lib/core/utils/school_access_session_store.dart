/**
 * WHAT:
 * school_access_session_store saves and restores the pre-login gate grant.
 * WHY:
 * Refresh should not immediately repeat School Access, while expired or
 * malformed grants must never reveal role or Quick Fill information.
 * HOW:
 * Serialize the narrow group/token/expiry model into browser sessionStorage on
 * web and the platform fallback elsewhere, clearing unusable values on read.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import '../../shared/models/school_access_session.dart';
import 'school_access_storage_stub.dart'
    if (dart.library.js_interop) 'school_access_storage_web.dart'
    as storage;

class SchoolAccessSessionStore {
  Future<void> saveSession(SchoolAccessSession session) async {
    await storage.writeSchoolAccessValue(
      jsonEncode({
        'accessGroup': session.accessGroup.name,
        'gateToken': session.gateToken,
        'expiresAt': session.expiresAt.toUtc().toIso8601String(),
      }),
    );
  }

  Future<SchoolAccessSession?> restoreSession() async {
    final rawValue = (await storage.readSchoolAccessValue() ?? '').trim();
    if (rawValue.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid school access session.');
      }
      final session = SchoolAccessSession.fromJson(decoded);
      if (session.isExpired) {
        // WHY: The client expiry is a UX boundary; the backend still verifies
        // the signed expiry before returning any account data.
        await clearSession();
        return null;
      }
      return session;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() => storage.clearSchoolAccessValue();
}
