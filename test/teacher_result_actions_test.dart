/**
 * WHAT:
 * Tests teacher Redo/Move visibility and the shared Result actions layout.
 * WHY:
 * These controls must only appear for submitted Theory/Essay evidence and must
 * stay beside existing result actions without narrow-screen overflow.
 * HOW:
 * Build typed mission fixtures, exercise the eligibility predicate, and pump
 * the exact wrapping action widget at desktop and mobile widths.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/teacher/presentation/teacher_session_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  MissionPayload mission({
    required String format,
    required int questionCount,
    String resultPackageId = 'result-1',
    bool evidenceCurrentExcluded = false,
  }) {
    return MissionPayload.fromJson({
      'id': '$format-$questionCount',
      'title': 'Mission',
      'draftFormat': format,
      'questionCount': questionCount,
      'taskCodes': ['P1'],
      'status': 'published',
      'latestResultPackageId': resultPackageId,
      'evidenceCurrentExcluded': evidenceCurrentExcluded,
      'scoreTotal': questionCount,
    });
  }

  test(
    'Redo and Move eligibility is limited to current submitted Theory/Essay',
    () {
      expect(
        canShowTeacherEvidenceActions(
          mission(format: 'THEORY', questionCount: 3),
        ),
        isTrue,
      );
      expect(
        canShowTeacherEvidenceActions(
          mission(format: 'ESSAY_BUILDER', questionCount: 10),
        ),
        isTrue,
      );
      for (final count in [5, 8, 10]) {
        expect(
          canShowTeacherEvidenceActions(
            mission(format: 'QUESTIONS', questionCount: count),
          ),
          isFalse,
        );
      }
      expect(
        canShowTeacherEvidenceActions(
          mission(format: 'THEORY', questionCount: 3, resultPackageId: ''),
        ),
        isFalse,
      );
      expect(
        canShowTeacherEvidenceActions(
          mission(
            format: 'THEORY',
            questionCount: 3,
            evidenceCurrentExcluded: true,
          ),
        ),
        isFalse,
      );
    },
  );

  Widget harness(double width) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: TeacherMissionResultActions(
              missionId: 'mission-1',
              sendLabel: 'Send result',
              onSend: () {},
              viewLabel: 'View result',
              onView: () {},
              redoLabel: 'Redo',
              onRedo: () {},
              moveLabel: 'Move',
              onMove: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('all four actions share one row when space allows', (
    tester,
  ) async {
    await tester.pumpWidget(harness(760));
    expect(find.text('Send result'), findsOneWidget);
    expect(find.text('View result'), findsOneWidget);
    expect(find.byKey(const Key('result_redo_mission-1')), findsOneWidget);
    expect(find.byKey(const Key('result_move_mission-1')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Send result')).dy,
      tester.getTopLeft(find.text('Redo')).dy,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('result_actions_mission-1')),
        matching: find.byType(OutlinedButton),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('Result actions wrap on narrow width without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(harness(250));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Send result'), findsOneWidget);
    expect(find.text('View result'), findsOneWidget);
    expect(find.text('Redo'), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Move')).dy,
      greaterThan(tester.getTopLeft(find.text('Send result')).dy),
    );
  });

  test('Move preview and confirmation use separate API requests', () async {
    final requests = <http.Request>[];
    final api = FocusMissionApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/move-preview')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'preview': {
                'sourceTaskCode': 'P1',
                'targetTaskCode': 'P2',
                'stage': 'ESSAY_BUILDER',
                'sourceLabel': 'P1 Essay',
                'targetLabel': 'P2 Essay',
                'studentAnswerRetained': true,
                'olderSourceEvidenceAvailable': false,
                'sourceOutcome': 'redo_required',
                'targetOutcome': 'moved_evidence',
                'targetConflict': true,
                'sourcePrompts': ['Source prompt'],
                'targetPrompts': ['Target prompt'],
                'theoryPromptMismatchWarning': false,
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'success': true, 'move': {}}), 201);
      }),
    );

    final preview = await api.previewTeacherResultMove(
      token: 'token',
      resultPackageId: 'result-1',
      targetTaskCode: 'P2',
    );
    expect(preview.sourceOutcome, 'redo_required');
    expect(preview.targetConflict, isTrue);
    expect(requests, hasLength(1));

    await api.moveTeacherResultEvidence(
      token: 'token',
      resultPackageId: 'result-1',
      targetTaskCode: 'P2',
      replaceTargetEvidence: true,
    );
    expect(requests, hasLength(2));
    expect(requests[0].url.path, endsWith('/move-preview'));
    expect(requests[1].url.path, endsWith('/move-task-focus'));
    expect(jsonDecode(requests[1].body), {
      'targetTaskCode': 'P2',
      'replaceTargetEvidence': true,
    });
  });
}
