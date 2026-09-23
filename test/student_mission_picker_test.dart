/**
 * WHAT:
 * Tests the compact student mission chooser and its dynamic filters.
 * WHY:
 * Students must be able to separate task focuses and mission formats on a
 * narrow screen without oversized cards or inaccessible list items.
 * HOW:
 * Pump representative assigned missions, exercise both filter groups, and
 * scroll to the final compact row at a phone-sized viewport.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/theme/app_theme.dart';
import 'package:focus_mission_app/features/student/presentation/student_dashboard_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';

void main() {
  MissionPayload mission({
    required String id,
    required String title,
    required String format,
    required int questionCount,
    required List<String> taskCodes,
    Map<String, String> assessmentSequenceByTaskCode = const {},
  }) {
    return MissionPayload.fromJson({
      'id': id,
      'title': title,
      'draftFormat': format,
      'questionCount': questionCount,
      'taskCodes': taskCodes,
      'assessmentSequenceByTaskCode': assessmentSequenceByTaskCode,
      'status': 'published',
      'sessionType': 'morning',
      'subject': {'id': 'business', 'name': 'Business'},
    });
  }

  Widget harness(List<MissionPayload> missions) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: StudentMissionPickerSheet(missions: missions)),
    );
  }

  final representativeMissions = <MissionPayload>[
    mission(
      id: 'objective-p1',
      title: 'P1 Objective',
      format: 'QUESTIONS',
      questionCount: 5,
      taskCodes: const ['P1'],
    ),
    mission(
      id: 'theory-p2',
      title: 'P2 Theory',
      format: 'THEORY',
      questionCount: 2,
      taskCodes: const ['P2'],
    ),
    mission(
      id: 'essay-p3',
      title: 'P3 Essay',
      format: 'ESSAY_BUILDER',
      questionCount: 10,
      taskCodes: const ['P3'],
    ),
    mission(
      id: 'assessment-a-m1',
      title: 'M1 Assessment A',
      format: 'QUESTIONS',
      questionCount: 10,
      taskCodes: const ['M1'],
      assessmentSequenceByTaskCode: const {'M1': 'A'},
    ),
    mission(
      id: 'assessment-b-d1',
      title: 'D1 Assessment B',
      format: 'QUESTIONS',
      questionCount: 10,
      taskCodes: const ['D1'],
      assessmentSequenceByTaskCode: const {'D1': 'B'},
    ),
  ];

  testWidgets('separates Objective Theory Essay and Assessment missions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(harness(representativeMissions));
    await tester.pump();

    expect(find.text('Objective'), findsOneWidget);
    expect(find.text('Theory'), findsOneWidget);
    expect(find.text('Essay'), findsOneWidget);
    expect(find.text('Assessment A'), findsOneWidget);
    expect(find.text('Assessment B'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('student-mission-type-filters')),
        matching: find.text('Theory'),
      ),
    );
    await tester.pump();

    expect(find.text('1 mission'), findsOneWidget);
    expect(find.byKey(const Key('student-mission-theory-p2')), findsOneWidget);
    expect(find.byKey(const Key('student-mission-objective-p1')), findsNothing);
    expect(find.byKey(const Key('student-mission-essay-p3')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters task focuses using only codes that are present', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(harness(representativeMissions));
    await tester.pump();

    for (final code in const ['P1', 'P2', 'P3', 'M1', 'D1']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('student-mission-task-filters')),
          matching: find.text(code),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('P4'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('student-mission-task-filters')),
        matching: find.text('M1'),
      ),
    );
    await tester.pump();

    expect(find.text('1 mission'), findsOneWidget);
    expect(
      find.byKey(const Key('student-mission-assessment-a-m1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('student-mission-theory-p2')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slim rows keep the final mission reachable on a small screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final missions = List<MissionPayload>.generate(
      14,
      (index) => mission(
        id: 'mission-$index',
        title: index == 13 ? 'Final M1 Mission' : 'Mission ${index + 1}',
        format: index.isEven ? 'QUESTIONS' : 'THEORY',
        questionCount: index.isEven ? 5 : 2,
        taskCodes: [index < 7 ? 'P${index + 1}' : 'M${index - 6}'],
      ),
    );

    await tester.pumpWidget(harness(missions));
    await tester.pump();

    final firstRow = find.byKey(const Key('student-mission-mission-0'));
    expect(firstRow, findsOneWidget);
    expect(tester.getSize(firstRow).height, lessThan(80));

    await tester.scrollUntilVisible(
      find.byKey(const Key('student-mission-mission-13')),
      220,
      scrollable: find.descendant(
        of: find.byKey(const Key('student-mission-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Final M1 Mission'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
