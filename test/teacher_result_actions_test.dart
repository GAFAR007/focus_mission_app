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
    String? id,
    String title = 'Mission',
    List<String> taskCodes = const ['P1'],
    Map<String, String> assessmentSequenceByTaskCode = const {},
    String resultPackageId = 'result-1',
    bool evidenceCurrentExcluded = false,
  }) {
    return MissionPayload.fromJson({
      'id': id ?? '$format-$questionCount',
      'title': title,
      'draftFormat': format,
      'questionCount': questionCount,
      'taskCodes': taskCodes,
      'assessmentSequenceByTaskCode': assessmentSequenceByTaskCode,
      'status': 'published',
      'latestResultPackageId': resultPackageId,
      'evidenceCurrentExcluded': evidenceCurrentExcluded,
      'scoreTotal': questionCount,
      'xpReward': 30,
      'subject': {'id': 'business', 'name': 'Business'},
      'availableOnDate': '2026-09-23',
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

  Widget assignedMissionsHarness({
    required double width,
    required List<MissionPayload> missions,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: TeacherAssignedMissionsPanel(
                missions: missions,
                sendingResultMissionIds: const {},
                isExpanded: true,
                onToggleExpanded: () {},
                onEdit: (_) {},
                onMoveBackToDraft: (_) {},
                onSendResult: (_) {},
                onViewResult: (_) {},
                onRedoResult: (_) {},
                onMoveResult: (_) {},
                resultEvidenceActionMissionIds: const {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<MissionPayload> assignedMissions() {
    return [
      mission(
        id: 'objective-p1',
        title: 'P1 Objective',
        format: 'QUESTIONS',
        questionCount: 5,
        resultPackageId: '',
      ),
      mission(
        id: 'theory-p1',
        title: 'P1 Theory',
        format: 'THEORY',
        questionCount: 3,
      ),
      mission(
        id: 'essay-p2',
        title: 'P2 Essay',
        format: 'ESSAY_BUILDER',
        questionCount: 10,
        taskCodes: const ['P2'],
        resultPackageId: '',
      ),
      mission(
        id: 'assessment-a-p2',
        title: 'P2 Assessment A',
        format: 'QUESTIONS',
        questionCount: 10,
        taskCodes: const ['P2'],
        assessmentSequenceByTaskCode: const {'P2': 'A'},
        resultPackageId: '',
      ),
      mission(
        id: 'assessment-b-p2',
        title: 'P2 Assessment B',
        format: 'QUESTIONS',
        questionCount: 10,
        taskCodes: const ['P2'],
        assessmentSequenceByTaskCode: const {'P2': 'B'},
        resultPackageId: '',
      ),
    ];
  }

  testWidgets('Assigned Missions combines level and type filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      assignedMissionsHarness(width: 760, missions: assignedMissions()),
    );
    await tester.pump();

    expect(find.byKey(const Key('assigned_filter_all')), findsOneWidget);
    expect(find.byKey(const Key('assigned_level_filter_all')), findsOneWidget);
    expect(find.byKey(const Key('assigned_level_filter_p1')), findsOneWidget);
    expect(find.byKey(const Key('assigned_level_filter_p2')), findsOneWidget);
    expect(find.byKey(const Key('assigned_level_filter_p3')), findsOneWidget);
    expect(find.byKey(const Key('assigned_level_filter_p4')), findsOneWidget);
    expect(find.byKey(const Key('assigned_level_filter_m1')), findsOneWidget);
    expect(find.byKey(const Key('assigned_level_filter_m2')), findsOneWidget);
    expect(find.byKey(const Key('assigned_level_filter_m3')), findsOneWidget);
    expect(find.byKey(const Key('assigned_filter_objective')), findsOneWidget);
    expect(find.byKey(const Key('assigned_filter_theory')), findsOneWidget);
    expect(find.byKey(const Key('assigned_filter_essay')), findsOneWidget);
    expect(
      find.byKey(const Key('assigned_filter_assessmentA')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('assigned_filter_assessmentB')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('assigned_mission_objective-p1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('assigned_mission_essay-p2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('assigned_level_filter_p2')));
    await tester.pump();

    expect(find.text('P1 Objective'), findsNothing);
    expect(find.text('P1 Theory'), findsNothing);
    expect(find.text('P2 Essay'), findsOneWidget);
    expect(
      find.byKey(const Key('assigned_mission_objective-p1')),
      findsNothing,
    );
    expect(find.byKey(const Key('assigned_mission_essay-p2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('assigned_filter_assessmentA')));
    await tester.pump();

    expect(find.text('P2 Assessment A'), findsOneWidget);
    expect(find.text('P2 Assessment B'), findsNothing);
    expect(
      find.byKey(const Key('assigned_mission_assessment-a-p2')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('assigned_level_filter_all')));
    await tester.tap(find.byKey(const Key('assigned_filter_theory')));
    await tester.pump();

    expect(find.text('P1 Theory'), findsOneWidget);
    expect(find.text('P2 Assessment A'), findsNothing);
    expect(find.byKey(const Key('assigned_mission_theory-p1')), findsOneWidget);
    expect(find.byKey(const Key('assigned_mission_essay-p2')), findsNothing);
  });

  testWidgets('Assigned Missions stays compact on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      assignedMissionsHarness(width: 390, missions: assignedMissions()),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Result actions'), findsNothing);
    expect(
      find.text(
        'Buttons unlock after this mission has a saved result package.',
      ),
      findsNothing,
    );
    expect(find.text('P1 Objective'), findsOneWidget);
    expect(find.text('P2 Assessment A'), findsOneWidget);
    expect(find.text('Send result'), findsOneWidget);
    expect(find.text('View result'), findsOneWidget);
    expect(find.byKey(const Key('result_redo_theory-p1')), findsOneWidget);
    expect(find.byKey(const Key('result_move_theory-p1')), findsOneWidget);
  });

  testWidgets('assigned results page by eight and reset on filters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final missions = List.generate(
      17,
      (index) =>
          mission(
            id: 'page-$index',
            title: 'Mission ${index.toString().padLeft(2, '0')}',
            format: 'QUESTIONS',
            questionCount: 5,
            taskCodes: [index < 10 ? 'P1' : 'P2'],
            resultPackageId: '',
          ).copyWith(
            availableOnDate:
                '2026-09-${(index + 1).toString().padLeft(2, '0')}',
          ),
    );
    await tester.pumpWidget(
      assignedMissionsHarness(width: 1100, missions: missions),
    );
    expect(find.text('Showing 1–8 of 17'), findsOneWidget);
    expect(find.text('Mission 16'), findsOneWidget);
    expect(find.text('Mission 08'), findsNothing);
    final first = tester.getTopLeft(
      find.byKey(const Key('assigned_mission_page-16')),
    );
    final second = tester.getTopLeft(
      find.byKey(const Key('assigned_mission_page-15')),
    );
    expect(first.dy, second.dy);
    expect(second.dx, greaterThan(first.dx));
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Showing 9–16 of 17'), findsOneWidget);
    expect(find.text('Mission 16'), findsNothing);
    await tester.tap(find.byKey(const Key('assigned_level_filter_p1')));
    await tester.pump();
    expect(find.text('Showing 1–8 of 10'), findsOneWidget);
    expect(find.text('Mission 09'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'MISSION 00');
    await tester.pump();
    expect(find.text('Showing 1–1 of 1'), findsOneWidget);
    expect(find.text('Mission 00'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assigned status and search only change the visible results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final missions = assignedMissions();
    await tester.pumpWidget(
      assignedMissionsHarness(width: 1100, missions: missions),
    );
    await tester.tap(find.byKey(const Key('assigned_status_completed')));
    await tester.pump();
    expect(find.text('P1 Theory'), findsOneWidget);
    expect(find.text('P1 Objective'), findsNothing);
    await tester.tap(find.byKey(const Key('assigned_status_current')));
    await tester.pump();
    expect(find.text('P1 Theory'), findsNothing);
    expect(find.text('P1 Objective'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'business');
    await tester.pump();
    expect(find.text('Showing 1–4 of 4'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'essay');
    await tester.pump();
    expect(find.text('P2 Essay'), findsOneWidget);
    expect(find.text('Showing 1–1 of 1'), findsOneWidget);
    expect(missions.length, 5);
    expect(missions[1].latestResultPackageId, isNotEmpty);
    expect(tester.takeException(), isNull);
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
