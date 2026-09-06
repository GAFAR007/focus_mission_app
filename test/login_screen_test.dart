/**
 * WHAT:
 * Widget tests cover the production gated login form, protected Quick Fill
 * interactions, and responsive layout.
 * WHY:
 * Password visibility, keyboard flow, and demo-account linkage are easy to
 * regress during presentation changes and directly affect sign-in usability.
 * HOW:
 * Pump the real LoginScreen with a mocked protected directory response,
 * exercise its controls, and assert request headers, state, and layout.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/theme/app_theme.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/auth/presentation/login_screen.dart';
import 'package:focus_mission_app/shared/models/user_role.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('builds private quick-fill avatars from first and last names', () {
    expect(accountAvatarLetters('Ahmed Stockwin'), 'AHST');
    expect(accountAvatarLetters('Asia-Lei Waller'), 'ASWA');
    expect(accountAvatarLetters('Mohammed'), 'MO');
  });

  Future<void> pumpLogin(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
    void Function(http.Request request)? onRequest,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = FocusMissionApi(
      client: MockClient((request) async {
        onRequest?.call(request);
        return http.Response(
          jsonEncode({
            'accounts': [
              {
                'name': 'Synthetic Teacher',
                'email': 'teacher@example.invalid',
                'role': 'teacher',
                'subject': 'ICT',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: LoginScreen(
          role: UserRole.teacher,
          gateToken: 'synthetic-gate-token',
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses modern email and password keyboard actions', (
    tester,
  ) async {
    await pumpLogin(tester);

    final fields = tester.widgetList<EditableText>(find.byType(EditableText));
    final emailField = fields.elementAt(0);
    final passwordField = fields.elementAt(1);

    expect(emailField.keyboardType, TextInputType.emailAddress);
    expect(emailField.textInputAction, TextInputAction.next);
    expect(passwordField.textInputAction, TextInputAction.done);
    expect(passwordField.obscureText, isTrue);

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final updatedPasswordField = tester.widget<EditableText>(
      find.byType(EditableText).at(1),
    );
    expect(updatedPasswordField.focusNode.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Enter a password.'), findsOneWidget);
  });

  testWidgets('password visibility toggles without clearing its value', (
    tester,
  ) async {
    await pumpLogin(tester);

    final passwordFinder = find.byType(TextFormField).at(1);
    await tester.enterText(passwordFinder, 'keep-this-password');
    await tester.tap(find.byKey(const Key('password_visibility_toggle')));
    await tester.pump();

    var passwordField = tester.widget<EditableText>(
      find.byType(EditableText).at(1),
    );
    expect(passwordField.obscureText, isFalse);
    expect(passwordField.controller.text, 'keep-this-password');

    await tester.tap(find.byKey(const Key('password_visibility_toggle')));
    await tester.pump();

    passwordField = tester.widget<EditableText>(
      find.byType(EditableText).at(1),
    );
    expect(passwordField.obscureText, isTrue);
    expect(passwordField.controller.text, 'keep-this-password');
  });

  testWidgets('Quick Fill remains linked to the existing form controllers', (
    tester,
  ) async {
    await pumpLogin(tester);

    final emailFinder = find.byType(TextFormField).first;
    final passwordFinder = find.byType(TextFormField).at(1);
    await tester.enterText(emailFinder, 'temporary@example.com');
    await tester.enterText(passwordFinder, 'temporary-password');

    final accountFinder = find.text('Synthetic Teacher');
    await tester.ensureVisible(accountFinder);
    await tester.tap(accountFinder);
    await tester.pump();

    final fields = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(fields.elementAt(0).controller.text, 'teacher@example.invalid');
    expect(fields.elementAt(1).controller.text, isEmpty);
  });

  testWidgets('Quick Fill uses initials and does not list account emails', (
    tester,
  ) async {
    await pumpLogin(tester);

    final accountFinder = find.text('Synthetic Teacher');
    await tester.ensureVisible(accountFinder);
    await tester.pump();

    expect(find.text('SYTE'), findsOneWidget);
    expect(find.text('ICT teacher'), findsOneWidget);
    final accountChip = find
        .ancestor(
          of: find.text('Synthetic Teacher'),
          matching: find.byType(InkWell),
        )
        .first;
    expect(
      find.descendant(
        of: accountChip,
        matching: find.text('teacher@example.invalid'),
      ),
      findsNothing,
    );
  });

  testWidgets('Quick Fill request carries the school access token', (
    tester,
  ) async {
    http.Request? capturedRequest;
    await pumpLogin(tester, onRequest: (request) => capturedRequest = request);

    expect(capturedRequest, isNotNull);
    expect(
      capturedRequest!.headers['X-School-Access-Token'],
      'synthetic-gate-token',
    );
    expect(capturedRequest!.url.queryParameters['role'], 'teacher');
  });

  testWidgets('lays out without overflow on a narrow phone', (tester) async {
    await pumpLogin(tester, size: const Size(320, 700));

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Quick fill accounts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
