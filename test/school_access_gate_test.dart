/**
 * WHAT:
 * Widget tests cover anonymous School Access, group-only role visibility,
 * protected Quick Fill navigation, invalid codes, restoration, and layout.
 * WHY:
 * The privacy boundary must prevent role/account disclosure before a backend
 * grant while keeping classroom login fast after a valid group code.
 * HOW:
 * Pump the real gate with a mocked API, return synthetic signed-session shapes,
 * navigate into login screens, and inspect visible content and requests.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/theme/app_theme.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/auth/presentation/role_selection_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<http.Request> requests;
  late FocusMissionApi api;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    requests = <http.Request>[];
    api = FocusMissionApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/access-gate/verify')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final group = switch (body['code']) {
            'student-test-code' => 'student',
            'staff-test-code' => 'staff',
            'management-test-code' => 'management',
            _ => null,
          };
          if (group == null) {
            return http.Response(
              jsonEncode({
                'message': "That access code wasn't recognised.",
                'statusCode': 401,
              }),
              401,
            );
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'accessGroup': group,
              'gateToken': '$group-synthetic-gate-token',
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
            }),
            200,
          );
        }

        if (request.url.path.endsWith('/auth/demo-accounts')) {
          final role = request.url.queryParameters['role'];
          return http.Response(
            jsonEncode({
              'accounts': [
                {
                  'name': 'Synthetic ${_title(role)}',
                  'email': '$role@example.invalid',
                  'role': role,
                },
              ],
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({'message': 'Unexpected request.'}),
          500,
        );
      }),
    );
  });

  Future<void> pumpGate(
    WidgetTester tester, {
    Size size = const Size(1024, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: RoleSelectionScreen(api: api),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(
      find.byKey(const Key('school_access_code_field')),
      code,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'anonymous visitor sees School Access and no role or account data',
    (tester) async {
      await pumpGate(tester);

      expect(find.text('School Access'), findsOneWidget);
      expect(find.text('Student Login'), findsNothing);
      expect(find.text('Teacher Login'), findsNothing);
      expect(find.text('Learning Mentor'), findsNothing);
      expect(find.text('Management Login'), findsNothing);
      expect(find.text('Quick fill accounts'), findsNothing);
      expect(
        requests.where(
          (request) => request.url.path.endsWith('/auth/demo-accounts'),
        ),
        isEmpty,
      );
    },
  );

  testWidgets('access code starts obscured and can be revealed', (
    tester,
  ) async {
    await pumpGate(tester);
    var field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.obscureText, isTrue);

    await tester.tap(find.byKey(const Key('school_access_visibility_toggle')));
    await tester.pump();
    field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.obscureText, isFalse);
  });

  testWidgets('student grant reveals Student only', (tester) async {
    await pumpGate(tester);
    await enterCode(tester, 'student-test-code');

    expect(find.text('Student Login'), findsOneWidget);
    expect(find.text('Teacher Login'), findsNothing);
    expect(find.text('Learning Mentor'), findsNothing);
    expect(find.text('Management Login'), findsNothing);
  });

  testWidgets('staff grant reveals Teacher and Learning Mentor only', (
    tester,
  ) async {
    await pumpGate(tester);
    await enterCode(tester, 'staff-test-code');

    expect(find.text('Staff Access'), findsOneWidget);
    expect(find.text('Teacher Login'), findsOneWidget);
    expect(find.text('Learning Mentor'), findsOneWidget);
    expect(find.text('Student Login'), findsNothing);
    expect(find.text('Management Login'), findsNothing);
  });

  testWidgets('management grant reveals Management only', (tester) async {
    await pumpGate(tester);
    await enterCode(tester, 'management-test-code');

    expect(find.text('Management Access'), findsOneWidget);
    expect(find.text('Management Login'), findsOneWidget);
    expect(find.text('Student Login'), findsNothing);
    expect(find.text('Teacher Login'), findsNothing);
    expect(find.text('Learning Mentor'), findsNothing);
  });

  testWidgets('invalid code remains on gate with generic error', (
    tester,
  ) async {
    await pumpGate(tester);
    await enterCode(tester, 'wrong-test-code');

    expect(find.text('School Access'), findsOneWidget);
    expect(find.text("That access code wasn't recognised."), findsOneWidget);
    expect(find.text('Student Login'), findsNothing);
  });

  testWidgets('student Quick Fill still works after gate verification', (
    tester,
  ) async {
    await pumpGate(tester);
    await enterCode(tester, 'student-test-code');
    await tester.tap(find.text('Student Login'));
    await tester.pumpAndSettle();

    expect(find.text('Quick fill accounts'), findsOneWidget);
    expect(find.text('Synthetic Student'), findsOneWidget);
    final quickFillRequest = requests.lastWhere(
      (request) => request.url.path.endsWith('/auth/demo-accounts'),
    );
    expect(quickFillRequest.url.queryParameters['role'], 'student');
    expect(
      quickFillRequest.headers['X-School-Access-Token'] ??
          quickFillRequest.headers['x-school-access-token'],
      'student-synthetic-gate-token',
    );
  });

  testWidgets('staff Quick Fill still works for its selected role', (
    tester,
  ) async {
    await pumpGate(tester);
    await enterCode(tester, 'staff-test-code');
    await tester.tap(find.text('Learning Mentor'));
    await tester.pumpAndSettle();

    expect(find.text('Synthetic Mentor'), findsOneWidget);
    final quickFillRequest = requests.lastWhere(
      (request) => request.url.path.endsWith('/auth/demo-accounts'),
    );
    expect(quickFillRequest.url.queryParameters['role'], 'mentor');
  });

  testWidgets('valid gate grant survives a normal widget refresh', (
    tester,
  ) async {
    await pumpGate(tester);
    await enterCode(tester, 'staff-test-code');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: RoleSelectionScreen(api: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff Access'), findsOneWidget);
    expect(find.text('School Access'), findsNothing);
  });

  for (final size in [const Size(320, 700), const Size(1280, 900)]) {
    testWidgets('School Access is usable at ${size.width.toInt()}px', (
      tester,
    ) async {
      await pumpGate(tester, size: size);

      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

String _title(String? value) {
  final normalized = value ?? '';
  if (normalized.isEmpty) {
    return '';
  }
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}
