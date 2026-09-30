/**
 * WHAT:
 * Tests authenticated-session restoration and independent school-gate storage.
 * WHY:
 * Existing users must bypass School Access on refresh, while logout should
 * clear real authentication without unnecessarily clearing the valid gate.
 * HOW:
 * Save synthetic auth and gate grants, restore identity through a mocked `/me`,
 * then clear auth and confirm the separate gate grant remains available.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/auth_session_store.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/core/utils/school_access_session_store.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:focus_mission_app/shared/models/school_access_session.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'authenticated session restores directly through the existing user API',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final authStore = AuthSessionStore();
      await authStore.saveSession(
        const AuthSession(
          token: 'synthetic-user-token',
          user: AppUser(
            id: 'student-1',
            name: 'Cached Learner',
            role: 'student',
          ),
        ),
      );
      final api = FocusMissionApi(
        client: MockClient((request) async {
          expect(request.url.path.endsWith('/auth/me'), isTrue);
          expect(
            request.headers['Authorization'],
            'Bearer synthetic-user-token',
          );
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'student-1',
                'name': 'Live Learner',
                'schoolId': 'resolved-school',
                'role': 'student',
              },
            }),
            200,
          );
        }),
      );

      final restored = await authStore.restoreSession(api: api);

      expect(restored, isNotNull);
      expect(restored!.user.name, 'Live Learner');
      expect(restored.user.role, 'student');
      expect(restored.user.schoolId, 'resolved-school');
      expect(
        restored.user.copyWith(name: 'Updated').schoolId,
        'resolved-school',
      );
      final offlineApi = FocusMissionApi(
        client: MockClient((_) async => throw Exception('Network unavailable')),
      );
      final cached = await authStore.restoreSession(api: offlineApi);
      expect(cached!.user.schoolId, 'resolved-school');
      expect(cached.token, 'synthetic-user-token');
      expect(
        StudentSummary.fromJson({
          'id': 'student-1',
          'schoolId': 'resolved-school',
        }).schoolId,
        restored.user.schoolId,
      );
    },
  );

  test(
    'logout clears authentication but preserves an unexpired gate grant',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final authStore = AuthSessionStore();
      final gateStore = SchoolAccessSessionStore();
      await authStore.saveSession(
        const AuthSession(
          token: 'synthetic-user-token',
          user: AppUser(id: 'teacher-1', name: 'Teacher', role: 'teacher'),
        ),
      );
      await gateStore.saveSession(
        SchoolAccessSession(
          accessGroup: SchoolAccessGroup.staff,
          gateToken: 'synthetic-gate-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );

      await authStore.clearSession();

      final restoredGate = await gateStore.restoreSession();
      expect(restoredGate, isNotNull);
      expect(restoredGate!.accessGroup, SchoolAccessGroup.staff);
    },
  );
}
