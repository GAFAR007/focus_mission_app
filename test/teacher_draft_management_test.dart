/**
 * WHAT:
 * Verifies Daily and Assessment draft criterion filters and bulk controls.
 * WHY:
 * Teachers must manage only visible drafts for one student while task focus,
 * assessment A/B identity, reuse, and narrow-screen layout remain unchanged.
 * HOW:
 * Pump the public teacher draft screens with controlled MissionPayload values
 * and record archive/delete callbacks without making network requests.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/teacher/presentation/teacher_session_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:focus_mission_app/shared/widgets/criterion_filter_bar.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

MissionPayload draftMission({
  required String id,
  required String title,
  required String taskCode,
  required int questionCount,
  String assessmentSequence = '',
}) {
  return MissionPayload(
    id: id,
    title: title,
    teacherNote: '',
    sourceUnitText: 'Source',
    sourceRawText: 'Source',
    sourceFileName: '',
    sourceFileType: '',
    draftFormat: 'QUESTIONS',
    essayMode: '',
    draftJson: null,
    source: 'groq',
    status: 'draft',
    sessionType: 'morning',
    difficulty: 'medium',
    taskCodes: <String>[taskCode],
    assessmentSequenceByTaskCode: assessmentSequence.isEmpty
        ? const <String, String>{}
        : <String, String>{taskCode: assessmentSequence},
    xpReward: 20,
    xpEarned: 0,
    questionCount: questionCount,
    scoreCorrect: 0,
    scoreTotal: questionCount,
    scorePercent: 0,
    latestResultPackageId: '',
    questions: List<MissionQuestion>.generate(
      questionCount,
      (index) => MissionQuestion(
        id: '$id-question-$index',
        answerMode: 'multiple_choice',
        learningText: 'Learn first',
        learningVideoUrl: '',
        learningVideoPlacement: 'afterLearnFirst',
        prompt: 'Question ${index + 1}',
        options: const <String>['A', 'B', 'C', 'D'],
        correctIndex: 0,
        explanation: 'A',
        expectedAnswer: '',
        minWordCount: 0,
      ),
    ),
    subject: const MissionSubject(id: 'business', name: 'Business'),
  );
}

List<MissionPayload> dailyDrafts() => <MissionPayload>[
  draftMission(
    id: 'daily-p1',
    title: 'P1 Daily Q5',
    taskCode: 'P1',
    questionCount: 5,
  ),
  draftMission(
    id: 'daily-p2',
    title: 'P2 Daily Q5',
    taskCode: 'P2',
    questionCount: 5,
  ),
];

List<MissionPayload> assessmentDrafts() => <MissionPayload>[
  draftMission(
    id: 'assessment-p1-a',
    title: 'P1 Assessment A',
    taskCode: 'P1',
    questionCount: 10,
    assessmentSequence: 'A',
  ),
  draftMission(
    id: 'assessment-p1-b',
    title: 'P1 Assessment B',
    taskCode: 'P1',
    questionCount: 10,
    assessmentSequence: 'B',
  ),
  draftMission(
    id: 'assessment-p2-a',
    title: 'P2 Assessment A',
    taskCode: 'P2',
    questionCount: 10,
    assessmentSequence: 'A',
  ),
];

Future<void> pumpDaily(
  WidgetTester tester, {
  DraftManagementCallback? onArchive,
  DraftManagementCallback? onDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DailyDraftListScreen(
        studentName: 'Student One',
        missions: dailyDrafts(),
        onArchive: onArchive ?? (_) async => true,
        onDelete: onDelete ?? (_) async => true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpAssessments(
  WidgetTester tester, {
  DraftManagementCallback? onArchive,
  DraftManagementCallback? onDelete,
  Size size = const Size(900, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: AssessmentDraftListScreen(
        studentName: 'Student One',
        studentXp: 0,
        missions: assessmentDrafts(),
        assessmentDraftCounts: const <String, int>{'P1': 2, 'P2': 1},
        onArchive: onArchive ?? (_) async => true,
        onDelete: onDelete ?? (_) async => true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('criterion filtering returns a new list without mutating drafts', () {
    final original = dailyDrafts();
    final snapshot = List<MissionPayload>.of(original);
    final filtered = filterMissionsByTaskCode(original, 'P1');

    expect(filtered.map((mission) => mission.id), <String>['daily-p1']);
    expect(original, orderedEquals(snapshot));
    expect(original.length, 2);

    final assessments = assessmentDrafts();
    final p1Assessments = filterMissionsByTaskCode(assessments, 'P1');
    expect(
      p1Assessments.map((mission) => mission.assessmentSequenceByTaskCode),
      <Map<String, String>>[
        <String, String>{'P1': 'A'},
        <String, String>{'P1': 'B'},
      ],
    );
    expect(assessments[2].assessmentSequenceByTaskCode, <String, String>{
      'P2': 'A',
    });
  });

  testWidgets(
    'Daily drafts default to All and filter P1 and P2 independently',
    (tester) async {
      await pumpDaily(tester);

      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('criterion-filter-All')))
            .selected,
        isTrue,
      );
      expect(find.text('P1 Daily Q5'), findsOneWidget);
      expect(find.text('P2 Daily Q5'), findsOneWidget);

      await tester.tap(find.byKey(const Key('criterion-filter-P1')));
      await tester.pumpAndSettle();
      expect(find.text('P1 Daily Q5'), findsOneWidget);
      expect(find.text('P2 Daily Q5'), findsNothing);

      await tester.tap(find.byKey(const Key('criterion-filter-P2')));
      await tester.pumpAndSettle();
      expect(find.text('P1 Daily Q5'), findsNothing);
      expect(find.text('P2 Daily Q5'), findsOneWidget);

      await tester.tap(find.byKey(const Key('criterion-filter-P3')));
      await tester.pumpAndSettle();
      expect(
        find.text('No P3 daily drafts for this student yet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Assessment drafts default to All and P1 never shows P2', (
    tester,
  ) async {
    await pumpAssessments(tester);

    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('criterion-filter-All')))
          .selected,
      isTrue,
    );
    expect(find.text('P1 Assessment A'), findsOneWidget);
    expect(find.text('P2 Assessment A'), findsOneWidget);

    await tester.tap(find.byKey(const Key('criterion-filter-P1')));
    await tester.pumpAndSettle();
    expect(find.text('P1 Assessment A'), findsOneWidget);
    expect(find.text('P1 Assessment B'), findsOneWidget);
    expect(find.text('P2 Assessment A'), findsNothing);

    await tester.tap(find.byKey(const Key('criterion-filter-P2')));
    await tester.pumpAndSettle();
    expect(find.text('P1 Assessment A'), findsNothing);
    expect(find.text('P2 Assessment A'), findsOneWidget);
  });

  testWidgets('Daily selection archive and delete controls stay available', (
    tester,
  ) async {
    var archivedIds = <String>[];
    await pumpDaily(
      tester,
      onArchive: (missions) async {
        archivedIds = missions.map((mission) => mission.id).toList();
        return true;
      },
    );
    await tester.tap(find.byKey(const Key('select-drafts-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P1 Daily Q5'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive-selected-button')), findsOneWidget);
    expect(find.byKey(const Key('delete-selected-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('archive-selected-button')));
    await tester.pumpAndSettle();
    expect(archivedIds, <String>['daily-p1']);
    expect(find.text('P1 Daily Q5'), findsNothing);
    expect(find.text('P2 Daily Q5'), findsOneWidget);
  });

  testWidgets('assessment selection supports one and multiple visible drafts', (
    tester,
  ) async {
    await pumpAssessments(tester);
    await tester.tap(find.byKey(const Key('select-drafts-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('P1 Assessment A'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('P1 Assessment B'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('changing assessment criterion clears hidden selections', (
    tester,
  ) async {
    await pumpAssessments(tester);
    await tester.tap(find.byKey(const Key('select-drafts-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P1 Assessment A'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byKey(const Key('criterion-filter-P2')));
    await tester.pumpAndSettle();
    expect(find.text('Selection mode active'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('archive-selected-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('assessment bulk archive removes only selected active drafts', (
    tester,
  ) async {
    var archivedIds = <String>[];
    await pumpAssessments(
      tester,
      onArchive: (missions) async {
        archivedIds = missions.map((mission) => mission.id).toList();
        return true;
      },
    );
    await tester.tap(find.byKey(const Key('select-drafts-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P1 Assessment A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('archive-selected-button')));
    await tester.pumpAndSettle();

    expect(archivedIds, <String>['assessment-p1-a']);
    expect(find.text('P1 Assessment A'), findsNothing);
    expect(find.text('P1 Assessment B'), findsOneWidget);
    expect(find.text('P2 Assessment A'), findsOneWidget);
  });

  testWidgets('assessment delete confirms count before deleting selections', (
    tester,
  ) async {
    var deletedIds = <String>[];
    await pumpAssessments(
      tester,
      onDelete: (missions) async {
        deletedIds = missions.map((mission) => mission.id).toList();
        return true;
      },
    );
    await tester.tap(find.byKey(const Key('select-drafts-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P1 Assessment A'));
    await tester.ensureVisible(find.text('P1 Assessment B'));
    await tester.tap(find.text('P1 Assessment B'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-selected-button')));
    await tester.pumpAndSettle();

    expect(find.text('2 drafts will be permanently deleted.'), findsOneWidget);
    expect(deletedIds, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(deletedIds, <String>['assessment-p1-a', 'assessment-p1-b']);
    expect(find.text('P2 Assessment A'), findsOneWidget);
  });

  testWidgets('reuse remains available outside selection mode', (tester) async {
    await pumpAssessments(tester);
    expect(find.text('Use for another student'), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('select-drafts-button')));
    await tester.pumpAndSettle();
    expect(find.text('Use for another student'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Use for another student'), findsNWidgets(3));
  });

  testWidgets('assessment draft controls remain usable on a narrow phone', (
    tester,
  ) async {
    await pumpAssessments(tester, size: const Size(390, 844));
    expect(find.byKey(const Key('criterion-filter-scroll')), findsOneWidget);
    expect(find.byKey(const Key('select-drafts-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('draft management API carries the selected student scope', () async {
    final requests = <http.Request>[];
    final api = FocusMissionApi(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{"success":true}', 200);
      }),
    );

    await api.archiveTeacherMission(
      token: 'teacher-token',
      studentId: 'student-1',
      missionId: 'mission-1',
    );
    await api.deleteTeacherMission(
      token: 'teacher-token',
      studentId: 'student-1',
      missionId: 'mission-2',
    );

    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, '/api/teacher/missions/mission-1/archive');
    expect(requests[0].body, contains('student-1'));
    expect(requests[1].method, 'DELETE');
    expect(requests[1].url.queryParameters['studentId'], 'student-1');
  });
}
