/**
 * WHAT:
 * Tests the shared result-report presentation and download HTML mapping.
 * WHY:
 * View Result and the teacher history download must keep names, answer states,
 * duration formatting, and labels identical as the report evolves.
 * HOW:
 * Exercise the pure presentation helpers with a typed immutable result-package
 * fixture and assert the generated HTML contains only the intended labels.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/teacher/models/result_report_presentation.dart';
import 'package:focus_mission_app/features/teacher/presentation/result_report_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('formats result durations for staff readability', () {
    expect(formatResultDuration(2207), '36 min 47 sec');
    expect(formatResultDuration(125), '2 min 5 sec');
    expect(formatResultDuration(45), '0 min 45 sec');
    expect(formatResultDuration(-1), '0 min 0 sec');
  });

  test('builds dynamic student answer labels with possessives', () {
    expect(
      resultStudentAnswerHeading('Ahmed Stockwin'),
      "AHMED STOCKWIN'S ANSWER",
    );
    expect(
      resultCompactAnswerLabel('Ahmed Stockwin', isCorrect: true),
      "Ahmed's answer • Correct",
    );
    expect(resultPossessiveName('James'), "James'");
  });

  test('normalizes objective answer states without Selected labels', () {
    final presentation = ResultObjectiveQuestionPresentation.fromEvidence({
      'questionText': 'Which service is a marketplace?',
      'options': {'A': 'Tesco', 'B': 'Amazon', 'C': 'Netflix', 'D': 'None'},
      'selectedOptionLetter': 'A',
      'selectedAnswer': 'Tesco',
      'correctOptionLetter': 'B',
      'correctAnswer': 'Amazon',
      'correctness': false,
      'pointsEarned': 0,
      'maxPoints': 1,
    }, studentName: 'Ahmed Stockwin');

    expect(
      presentation.stateFor('A'),
      ResultOptionVisualState.studentIncorrect,
    );
    expect(presentation.stateFor('B'), ResultOptionVisualState.correct);
    expect(presentation.optionTag('A'), "Ahmed's answer");
    expect(presentation.optionTag('B'), 'Correct answer');
    expect(presentation.optionTag('A'), isNot(contains('Selected')));
  });

  test('download HTML uses the same dynamic result presentation data', () {
    final result = ResultHistoryItem.fromJson({
      'id': 'history-1',
      'resultPackageId': 'package-1',
      'missionId': 'mission-1',
      'title': 'P1 Assessment A',
      'draftFormat': 'QUESTIONS',
      'status': 'submitted',
      'sessionType': 'afternoon',
      'questionCount': 1,
      'scoreCorrect': 0,
      'scoreTotal': 1,
      'scorePercent': 0,
      'xpReward': 20,
      'xpEarned': 0,
      'taskCodes': ['P1'],
      'subject': {'id': 'business', 'name': 'Business'},
      'availableOnDate': '2026-09-23',
    });
    final resultPackage = ResultPackageData.fromJson({
      'id': 'package-1',
      'studentId': 'student-1',
      'teacherId': 'teacher-1',
      'resultKind': 'mission',
      'missionId': 'mission-1',
      'missionType': 'QUESTIONS',
      'meta': {
        'studentName': 'Ahmed Stockwin',
        'studentId': 'student-1',
        'teacherId': 'teacher-1',
        'missionId': 'mission-1',
        'missionTitle': 'P1 Assessment A',
        'subject': 'Business',
        'taskCodes': ['P1'],
        'assignedDate': '2026-09-23',
        'submitTime': '2026-09-23T12:00:00.000Z',
        'durationSeconds': 2207,
        'score': {'correct': 0, 'total': 1, 'percent': 0},
        'xpAwarded': 0,
      },
      'evidence': {
        'format': 'QUESTIONS',
        'questions': [
          {
            'itemType': 'OBJECTIVE',
            'questionText': 'Which service is a marketplace?',
            'options': {
              'A': 'Tesco',
              'B': 'Amazon',
              'C': 'Netflix',
              'D': 'None',
            },
            'selectedOptionLetter': 'A',
            'selectedAnswer': 'Tesco',
            'correctOptionLetter': 'B',
            'correctAnswer': 'Amazon',
            'correctness': false,
            'pointsEarned': 0,
            'maxPoints': 1,
          },
        ],
      },
    });

    final html = const TeacherResultReportHtmlBuilder().build(
      studentName: 'Ahmed Stockwin',
      entries: [
        TeacherResultReportEntry(result: result, resultPackage: resultPackage),
      ],
      summaryLabel: '2026-09-23',
    );

    expect(html, contains('Ahmed Stockwin'));
    expect(html, contains('36 min 47 sec'));
    expect(html, contains('Ahmed&#39;s answer'));
    expect(html, contains('Correct answer'));
    expect(html, isNot(contains('Student answer')));
    expect(html, isNot(contains('Selected:')));
    expect(html, isNot(contains('2207s')));
  });

  testWidgets('View Result uses the shared student name and duration labels', (
    tester,
  ) async {
    final api = FocusMissionApi(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({'resultPackage': _resultPackageJson()}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ResultReportScreen(
          session: const AuthSession(
            token: 'teacher-token',
            user: AppUser(id: 'teacher-1', name: 'Teacher', role: 'teacher'),
          ),
          mission: MissionPayload.fromJson({
            'id': 'mission-1',
            'title': 'P1 Assessment A',
            'status': 'published',
            'draftFormat': 'QUESTIONS',
            'subject': {'id': 'business', 'name': 'Business'},
          }),
          student: const StudentSummary(
            id: 'student-1',
            name: 'Ahmed Stockwin',
            xp: 0,
            streak: 0,
          ),
          resultPackageId: 'package-1',
          api: api,
          readOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ahmed Stockwin'), findsWidgets);
    expect(find.text('36 min 47 sec'), findsOneWidget);
    expect(find.text("Ahmed's answer"), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(find.text('Student answer'), findsNothing);
    expect(find.text('Selected:'), findsNothing);
  });
}

Map<String, dynamic> _resultPackageJson() {
  return {
    'id': 'package-1',
    'studentId': 'student-1',
    'teacherId': 'teacher-1',
    'resultKind': 'mission',
    'missionId': 'mission-1',
    'missionType': 'QUESTIONS',
    'latestSendStatus': 'not_sent',
    'meta': {
      'studentName': 'Ahmed Stockwin',
      'studentId': 'student-1',
      'teacherId': 'teacher-1',
      'missionId': 'mission-1',
      'missionTitle': 'P1 Assessment A',
      'subject': 'Business',
      'taskCodes': ['P1'],
      'assignedDate': '2026-09-23',
      'startTime': '2026-09-23T11:23:13.000Z',
      'submitTime': '2026-09-23T12:00:00.000Z',
      'durationSeconds': 2207,
      'score': {'correct': 0, 'total': 1, 'percent': 0},
      'xpAwarded': 0,
    },
    'evidence': {
      'format': 'QUESTIONS',
      'questions': [
        {
          'itemType': 'OBJECTIVE',
          'questionText': 'Which service is a marketplace?',
          'options': {'A': 'Tesco', 'B': 'Amazon', 'C': 'Netflix', 'D': 'None'},
          'selectedOptionLetter': 'A',
          'selectedAnswer': 'Tesco',
          'correctOptionLetter': 'B',
          'correctAnswer': 'Amazon',
          'correctness': false,
          'pointsEarned': 0,
          'maxPoints': 1,
        },
      ],
    },
    'sendLogs': [],
  };
}
