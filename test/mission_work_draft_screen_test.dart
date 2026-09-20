/**
 * WHAT:
 * Tests student Theory and Essay Builder draft restoration and debounced save.
 * WHY:
 * Written work and guided progress must survive a browser refresh without
 * becoming final ResultPackage evidence.
 * HOW:
 * Inject a mocked FocusMissionApi into MissionPlayScreen and inspect the draft
 * GET/PUT traffic plus the restored text shown by the student UI.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/student/presentation/mission_play_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const session = AuthSession(
    token: 'student-token',
    user: AppUser(id: 'student-id', name: 'Student', role: 'student'),
  );

  StartedMission theoryMission() => StartedMission.fromJson({
    'startedAt': '2026-09-20T09:00:00.000Z',
    'studentId': 'student-id',
    'subjectId': 'subject-id',
    'sessionType': 'morning',
    'maxQuestions': 2,
    'mission': {
      'id': 'mission-theory',
      'title': 'Theory mission',
      'draftFormat': 'THEORY',
      'status': 'published',
      'sessionType': 'morning',
      'questionCount': 2,
      'subject': {'id': 'subject-id', 'name': 'Business'},
      'questions': [
        {
          'id': 'q1',
          'answerMode': 'short_answer',
          'prompt': 'Explain online sales.',
          'minWordCount': 3,
        },
        {
          'id': 'q2',
          'answerMode': 'short_answer',
          'prompt': 'Explain delivery.',
          'minWordCount': 3,
        },
      ],
    },
  });

  StartedMission essayMission() => StartedMission.fromJson({
    'startedAt': '2026-09-20T09:00:00.000Z',
    'studentId': 'student-id',
    'subjectId': 'subject-id',
    'sessionType': 'morning',
    'maxQuestions': 1,
    'mission': {
      'id': 'mission-essay',
      'title': 'Essay mission',
      'draftFormat': 'ESSAY_BUILDER',
      'status': 'published',
      'sessionType': 'morning',
      'questionCount': 1,
      'subject': {'id': 'subject-id', 'name': 'Business'},
      'draftJson': {
        'type': 'ESSAY_BUILDER',
        'mode': 'NORMAL',
        'targets': {
          'targetWordMin': 1,
          'targetWordMax': 500,
          'targetSentenceCount': 1,
          'targetBlankCount': 1,
        },
        'sentences': [
          {
            'id': 's1',
            'role': 'topic',
            'learnFirst': {
              'title': 'Learn first',
              'bullets': ['One', 'Two', 'Three'],
            },
            'parts': [
              {'type': 'text', 'value': 'Online sales are '},
              {
                'type': 'blank',
                'blankId': 'b1',
                'options': {
                  'A': 'useful.',
                  'B': 'silent.',
                  'C': 'paper.',
                  'D': 'closed.',
                },
                'correctOption': 'A',
              },
            ],
          },
        ],
      },
    },
  });

  StartedMission legacyCappedEssayMission() => StartedMission.fromJson({
    'startedAt': '2026-09-20T09:00:00.000Z',
    'studentId': 'student-id',
    'subjectId': 'subject-id',
    'sessionType': 'morning',
    'maxQuestions': 1,
    'mission': {
      'id': 'mission-legacy-essay-cap',
      'title': 'Legacy capped essay mission',
      'draftFormat': 'ESSAY_BUILDER',
      'status': 'published',
      'sessionType': 'morning',
      'questionCount': 1,
      'subject': {'id': 'subject-id', 'name': 'Business'},
      'draftJson': {
        'type': 'ESSAY_BUILDER',
        'mode': 'NORMAL',
        'targets': {
          'targetWordMin': 100,
          'targetWordMax': 140,
          'targetSentenceCount': 1,
          'targetBlankCount': 1,
        },
        'sentences': [
          {
            'id': 's1',
            'role': 'topic',
            'learnFirst': {
              'title': 'Learn first',
              'bullets': ['One', 'Two', 'Three'],
            },
            'parts': [
              {
                'type': 'text',
                'value': '${List.filled(144, 'guided').join(' ')} ',
              },
              {
                'type': 'blank',
                'blankId': 'b1',
                'options': {
                  'A': 'complete',
                  'B': 'other',
                  'C': 'another',
                  'D': 'last',
                },
                'correctOption': 'A',
              },
            ],
          },
        ],
      },
    },
  });

  testWidgets('Theory restores exact text and saves after the debounce', (
    tester,
  ) async {
    Map<String, dynamic>? savedBody;
    final api = FocusMissionApi(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'workDraft': {
                'missionId': 'mission-theory',
                'missionType': 'THEORY',
                'status': 'in_progress',
                'version': 2,
                'theoryResponses': [
                  {
                    'questionIndex': 0,
                    'answerText': 'My exact saved theory answer',
                    'wordCount': 5,
                  },
                ],
                'essayBuilder': {},
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        savedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'workDraft': {
              'missionId': 'mission-theory',
              'missionType': 'THEORY',
              'status': 'in_progress',
              'version': 3,
              'theoryResponses': savedBody!['theoryResponses'],
              'essayBuilder': {},
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MissionPlayScreen(
          session: session,
          startedMission: theoryMission(),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previousButton = find.text('Previous Question');
    await tester.ensureVisible(previousButton);
    await tester.tap(previousButton);
    await tester.pumpAndSettle();
    expect(find.text('My exact saved theory answer'), findsOneWidget);
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'Edited exact theory answer stays here');
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    final responses = savedBody!['theoryResponses'] as List<dynamic>;
    expect(responses.single['questionIndex'], 0);
    expect(
      responses.single['answerText'],
      'Edited exact theory answer stays here',
    );
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('each Theory question keeps its own pending debounce', (
    tester,
  ) async {
    final savedIndexes = <int>[];
    final api = FocusMissionApi(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'workDraft': {
                'missionId': 'mission-theory',
                'missionType': 'THEORY',
                'status': 'in_progress',
                'version': 1,
                'theoryResponses': const [],
                'essayBuilder': const {},
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final responses = body['theoryResponses'] as List<dynamic>;
        savedIndexes.add(responses.single['questionIndex'] as int);
        return http.Response(
          jsonEncode({
            'workDraft': {
              'missionId': 'mission-theory',
              'missionType': 'THEORY',
              'status': 'in_progress',
              'version': 2,
              'theoryResponses': responses,
              'essayBuilder': const {},
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MissionPlayScreen(
          session: session,
          startedMission: theoryMission(),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final continueButton = find.text('Continue to Question');
    if (continueButton.evaluate().isNotEmpty) {
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField).first, 'First draft answer');
    await tester.pump();
    final nextButton = find.text('Next Question');
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Second draft answer');
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(savedIndexes.toSet(), {0, 1});
  });

  testWidgets('Essay restores guided progress and final text', (tester) async {
    final api = FocusMissionApi(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'workDraft': {
              'missionId': 'mission-essay',
              'missionType': 'ESSAY_BUILDER',
              'status': 'in_progress',
              'version': 4,
              'theoryResponses': [],
              'essayBuilder': {
                'selectedAnswers': [
                  {'sentenceId': 's1', 'blankId': 'b1', 'selectedOption': 'A'},
                ],
                'currentSentenceIndex': 1,
                'finalEssayText': 'My exact saved final essay text',
              },
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MissionPlayScreen(
          session: session,
          startedMission: essayMission(),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Online sales are useful.'), findsWidgets);
    expect(find.text('My exact saved final essay text'), findsOneWidget);
    expect(find.text('Sentence 2 of 1'), findsNothing);
  });

  testWidgets('legacy 140-word draft uses the current 100-500 range', (
    tester,
  ) async {
    final api = FocusMissionApi(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'workDraft': {
              'missionId': 'mission-legacy-essay-cap',
              'missionType': 'ESSAY_BUILDER',
              'status': 'in_progress',
              'version': 2,
              'theoryResponses': [],
              'essayBuilder': {
                'selectedAnswers': [
                  {'sentenceId': 's1', 'blankId': 'b1', 'selectedOption': 'A'},
                ],
                'currentSentenceIndex': 1,
                'finalEssayText': List.filled(100, 'response').join(' '),
              },
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MissionPlayScreen(
          session: session,
          startedMission: legacyCappedEssayMission(),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // WHY: Existing missions can retain their stored 140 cap, but students
    // must receive the current policy without a production data rewrite.
    expect(find.text('Target words: 100-500'), findsOneWidget);
    expect(find.textContaining('above 140'), findsNothing);
    expect(find.text('Submit Essay Mission'), findsOneWidget);
  });
}
