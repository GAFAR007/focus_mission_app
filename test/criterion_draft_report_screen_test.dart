/**
 * WHAT:
 * Tests the teacher Draft Report's copyable evidence, editable comment state,
 * server-owned calculation rendering, and persisted comment payload.
 * WHY:
 * Pending evidence must never appear as a fake final score, and report wording
 * must remain separate from immutable student evidence.
 * HOW:
 * Render a mocked report response, edit a comment, save it, and inspect the PUT.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/teacher/presentation/criterion_draft_report_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> reportJson({String essayComment = 'Original feedback'}) {
  return {
    'title': 'Sudais Dahir — P1 Business Online Draft Report',
    'taskCode': 'P1',
    'criterionWording': 'Explain how a business operates online.',
    'criterionWordingAvailable': true,
    'q5': {
      'label': 'Q5 Daily',
      'status': 'scored',
      'resultPackageId': 'q5-result',
      'correct': 5,
      'total': 5,
      'percent': 100,
      'passed': true,
    },
    'q8': {
      'label': 'Q8 Revision',
      'status': 'scored',
      'resultPackageId': 'q8-result',
      'correct': 8,
      'total': 8,
      'percent': 100,
      'passed': true,
    },
    'essay': {
      'status': 'scored',
      'resultPackageId': 'essay-result',
      'question': 'Explain how online businesses reach customers.',
      'finalEssayText': 'Exact student essay wording.',
      'scoreCorrect': 19,
      'scoreTotal': 30,
      'percent': 63,
      'teacherComment': essayComment,
      'nextTime': 'Develop the conclusion.',
      'history': {
        'kind': 'move',
        'title': 'Moved from P1 to P2',
        'detail': 'Moved by Teacher',
        'at': '2026-09-23T10:00:00.000Z',
      },
    },
    'theory': {
      'status': 'scored',
      'resultPackageId': 'theory-result',
      'percent': 71,
      'passed': true,
      'history': {
        'kind': 'redo',
        'title': 'Redo attempt',
        'detail': 'Previous result: 68.8% · Current: Pending',
        'at': '2026-09-23T10:00:00.000Z',
      },
      'questions': [
        {
          'questionIndex': 0,
          'prompt': 'What is an online business?',
          'studentAnswer': 'Exact theory answer.',
          'originalTeacherScore': 71,
          'teacherComment': 'Clear answer.',
        },
      ],
    },
    'assessmentA': {
      'label': 'P1 Assessment A',
      'status': 'pending',
      'resultPackageId': '',
    },
    'assessmentB': {
      'label': 'P1 Assessment B',
      'status': 'not_created',
      'resultPackageId': '',
    },
    'calculation': {
      'status': 'pending',
      'overallPercent': null,
      'securedContribution': 47.45,
      'rows': [
        {
          'key': 'theory',
          'label': 'Theory',
          'weightPercent': 35,
          'percent': 71,
          'contribution': 24.85,
          'status': 'scored',
        },
        {
          'key': 'assessmentA',
          'label': 'Assessment A',
          'weightPercent': 35,
          'percent': null,
          'contribution': null,
          'status': 'pending',
        },
        {
          'key': 'essay',
          'label': 'Essay Builder - Final Essay',
          'weightPercent': 20,
          'percent': 63,
          'contribution': 12.6,
          'status': 'scored',
        },
        {
          'key': 'q5',
          'label': 'Q5 Daily',
          'weightPercent': 5,
          'percent': 100,
          'contribution': 5,
          'status': 'scored',
        },
        {
          'key': 'q8',
          'label': 'Q8 Revision',
          'weightPercent': 5,
          'percent': 100,
          'contribution': 5,
          'status': 'scored',
        },
      ],
    },
    'criterionStatus': {
      'status': 'not_passed',
      'passed': false,
      'reason': 'Assessment A is pending.',
    },
  };
}

void main() {
  testWidgets('renders selectable evidence and keeps overall score Pending', (
    tester,
  ) async {
    Map<String, dynamic>? savedBody;
    final api = FocusMissionApi(
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          savedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'report': reportJson(essayComment: 'Edited comment')}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'report': reportJson()}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CriterionDraftReportScreen(
          session: const AuthSession(
            token: 'teacher-token',
            user: AppUser(id: 'teacher-id', name: 'Teacher', role: 'teacher'),
          ),
          student: const StudentSummary(
            id: 'student-id',
            name: 'Sudais Dahir',
            xp: 0,
            streak: 0,
          ),
          subjectId: 'subject-id',
          taskCode: 'P1',
          missions: const [],
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(SelectableText, 'Exact student essay wording.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(SelectableText, 'Exact theory answer.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('evidence_history_move')), findsOneWidget);
    expect(find.byKey(const Key('evidence_history_redo')), findsOneWidget);
    final comment = find.byKey(const Key('essay_report_comment'));
    await tester.ensureVisible(comment);
    await tester.enterText(comment, 'Edited comment');

    await tester.scrollUntilVisible(
      find.byKey(const Key('criterion_report_overall_score')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('criterion_report_overall_score')),
      findsOneWidget,
    );
    expect(find.text('Pending'), findsWidgets);
    expect(
      find.text('Current secured contribution: 47.45 / 100'),
      findsOneWidget,
    );

    final saveButton = find.text('Save Draft');
    await tester.scrollUntilVisible(
      saveButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedBody?['essayTeacherComment'], 'Edited comment');
    expect(savedBody?['theoryQuestionComments'], isA<List<dynamic>>());
  });

  testWidgets('refresh rebuilds the live total after marking changes', (
    tester,
  ) async {
    var reportReads = 0;
    final api = FocusMissionApi(
      client: MockClient((request) async {
        reportReads += 1;
        final response = reportJson();
        if (reportReads > 1) {
          response['assessmentA'] = {
            'label': 'P1 Assessment A',
            'status': 'scored',
            'resultPackageId': 'assessment-result',
            'correct': 10,
            'total': 10,
            'percent': 100,
            'passed': true,
          };
          response['calculation'] = {
            'status': 'scored',
            'overallPercent': 82.45,
            'securedContribution': 82.45,
            'rows': [
              {
                'key': 'theory',
                'label': 'Theory',
                'weightPercent': 35,
                'percent': 71,
                'contribution': 24.85,
                'status': 'scored',
              },
              {
                'key': 'assessmentA',
                'label': 'Assessment A',
                'weightPercent': 35,
                'percent': 100,
                'contribution': 35,
                'status': 'scored',
              },
              {
                'key': 'essay',
                'label': 'Essay Builder - Final Essay',
                'weightPercent': 20,
                'percent': 63,
                'contribution': 12.6,
                'status': 'scored',
              },
              {
                'key': 'q5',
                'label': 'Q5 Daily',
                'weightPercent': 5,
                'percent': 100,
                'contribution': 5,
                'status': 'scored',
              },
              {
                'key': 'q8',
                'label': 'Q8 Revision',
                'weightPercent': 5,
                'percent': 100,
                'contribution': 5,
                'status': 'scored',
              },
            ],
          };
        }
        return http.Response(
          jsonEncode({'report': response}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CriterionDraftReportScreen(
          session: const AuthSession(
            token: 'teacher-token',
            user: AppUser(id: 'teacher-id', name: 'Teacher', role: 'teacher'),
          ),
          student: const StudentSummary(
            id: 'student-id',
            name: 'Sudais Dahir',
            xp: 0,
            streak: 0,
          ),
          subjectId: 'subject-id',
          taskCode: 'P1',
          missions: const [],
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('criterion_report_overall_score')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pending'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Refresh report'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('criterion_report_overall_score')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('82.45%'), findsOneWidget);
    expect(reportReads, 2);
    expect(tester.takeException(), isNull);
  });
}
