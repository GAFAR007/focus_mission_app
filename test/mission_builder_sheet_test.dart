/**
 * WHAT:
 * Verifies the responsive Review Draft workspace and protected Back action.
 * WHY:
 * The teacher editor must use the available viewport without mobile overflow
 * and must never silently discard changed draft content.
 * HOW:
 * Open the real mission-builder sheet with a saved draft at desktop and phone
 * sizes, inspect its rendered workspace, and exercise the dirty Back flow.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/teacher/presentation/mission_builder_sheet.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Review Draft uses a wide desktop workspace and protects edits', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 1000));
    await _openReviewDraft(tester);

    final workspace = find.byType(FractionallySizedBox).last;
    expect(tester.getSize(workspace).width, greaterThan(1250));
    expect(find.text('Review Draft'), findsOneWidget);
    expect(find.text('Draft only'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Changed title');
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Leave Review Draft?'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.text('Discard edits'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Review Draft'), findsOneWidget);
  });

  testWidgets('Review Draft fills a narrow phone without horizontal overflow', (
    tester,
  ) async {
    final overflowErrors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        overflowErrors.add(details);
        return;
      }
      previousErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousErrorHandler);

    await _setViewport(tester, const Size(390, 844));
    await _openReviewDraft(tester);

    final workspace = find.byType(FractionallySizedBox).last;
    expect(tester.getSize(workspace).width, 390);
    expect(find.text('Review Draft'), findsOneWidget);
    expect(overflowErrors, isEmpty);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _openReviewDraft(WidgetTester tester) async {
  final api = FocusMissionApi(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({'certifications': <dynamic>[]}),
        200,
        headers: const {'content-type': 'application/json'},
      ),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              showMissionBuilderSheet(
                context,
                session: const AuthSession(
                  token: 'teacher-token',
                  user: AppUser(
                    id: 'teacher-1',
                    name: 'Teacher One',
                    role: 'teacher',
                  ),
                ),
                student: const StudentSummary(
                  id: 'student-1',
                  name: 'Student One',
                  xp: 0,
                  streak: 0,
                ),
                subject: const SubjectSummary(
                  id: 'subject-1',
                  name: 'Business',
                ),
                sessionType: 'morning',
                targetDate: DateTime.now(),
                api: api,
                initialDraft: _draft(),
              );
            },
            child: const Text('Open review'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open review'));
  await tester.pumpAndSettle();
}

MissionPayload _draft() {
  return MissionPayload(
    id: 'mission-1',
    title: 'Business Online',
    teacherNote: 'Read carefully.',
    sourceUnitText: 'Business Online unit text.',
    sourceRawText: '',
    sourceFileName: '',
    sourceFileType: '',
    draftFormat: 'QUESTIONS',
    essayMode: '',
    draftJson: null,
    source: 'teacher_ai',
    status: 'draft',
    sessionType: 'morning',
    difficulty: 'medium',
    taskCodes: const ['P1'],
    xpReward: 30,
    xpEarned: 0,
    questionCount: 5,
    scoreCorrect: 0,
    scoreTotal: 5,
    scorePercent: 0,
    latestResultPackageId: '',
    questions: const [
      MissionQuestion(
        id: 'question-1',
        answerMode: 'multiple_choice',
        learningText: 'An online business trades using the internet.',
        prompt: 'What is an online business?',
        options: ['Online trade', 'A room', 'A timetable', 'A letter'],
        correctIndex: 0,
        explanation: 'Online trade is the correct definition.',
        expectedAnswer: '',
        minWordCount: 0,
      ),
    ],
  );
}
