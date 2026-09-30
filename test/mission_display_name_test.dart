/**
 * WHAT: Tests canonical mission naming across models, filters and downloads.
 * WHY: Legacy Objective and Theory work may share counts but must keep distinct identities.
 * HOW: Use immutable structured fixtures and the real student mission picker.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'package:flutter/material.dart';
import 'package:focus_mission_app/features/teacher/models/result_report_presentation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/features/student/presentation/student_dashboard_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:focus_mission_app/shared/models/mission_display_name.dart';

Map<String, dynamic> missionJson(
  String type,
  int count, {
  String code = 'P1',
}) => {
  'id': '$type-$count',
  'title': 'Business Morning Mission',
  'draftFormat': type,
  'questionCount': count,
  'taskCodes': [code],
  'subject': {'name': 'Business'},
  'sessionType': 'morning',
};

void main() {
  for (final example in [
    ('QUESTIONS', 8, 'P1', 'P1 Objective Q8'),
    ('QUESTIONS', 5, 'P1', 'P1 Objective Q5'),
    ('THEORY', 5, 'P1', 'P1 Theory Q5'),
    ('THEORY', 5, 'D1', 'D1 Theory Q5'),
    ('ESSAY_BUILDER', 30, 'P2', 'P2 Essay'),
    ('ESSAY_BUILDER', 10, 'M1', 'M1 Essay'),
  ]) {
    test('mission and history use ${example.$4}', () {
      final json = missionJson(example.$1, example.$2, code: example.$3);
      final mission = MissionPayload.fromJson(json);
      final history = ResultHistoryItem.fromJson({
        ...json,
        'missionId': 'mission-id',
      });
      expect(mission.displayTitle, example.$4);
      expect(history.displayTitle, example.$4);
      expect(history.toMissionContext().displayTitle, example.$4);
      expect(mission.title, 'Business Morning Mission');
      expect(mission.copyWith().displayTitle, example.$4);
    });
  }

  test(
    'custom and unknown titles survive while generated titles follow edits',
    () {
      expect(
        missionDisplayName(
          title: 'Investigating local businesses',
          type: 'THEORY',
          questionCount: 5,
        ),
        'Investigating local businesses',
      );
      expect(
        missionDisplayName(
          title: 'P1 Theory',
          type: 'THEORY',
          questionCount: 5,
        ),
        'P1 Theory',
      );
      expect(
        missionDisplayName(
          title: 'P1 Objective Q8',
          type: 'THEORY',
          taskCodes: ['P2'],
          questionCount: 5,
        ),
        'P2 Theory Q5',
      );
      final unknown = MissionPayload.fromJson({
        'title': 'Morning Mission',
        'questionCount': 5,
      });
      expect(unknown.displayTitle, 'Morning Mission');
      expect(unknown.copyWith().displayTitle, 'Morning Mission');
      expect(unknown.copyWith(draftFormat: 'THEORY').displayTitle, 'Theory Q5');
    },
  );

  test(
    'result naming uses evidence count and preserves raw submitted metadata',
    () {
      final package = ResultPackageData.fromJson({
        'missionType': 'THEORY',
        'meta': {
          'missionTitle': 'Business Afternoon Mission',
          'subject': 'Business',
          'taskCodes': ['P1'],
          'score': {'total': 100},
        },
        'evidence': {'questions': List.generate(5, (_) => <String, dynamic>{})},
      });
      expect(package.displayTitle, 'P1 Theory Q5');
      expect(package.meta.missionTitle, 'Business Afternoon Mission');
      expect(package.meta.scoreTotal, 100);
    },
  );

  test(
    'download HTML shares the legacy result heading without rewriting evidence',
    () {
      final result = ResultHistoryItem.fromJson({
        ...missionJson('THEORY', 5),
        'missionId': 'm',
      });
      final package = ResultPackageData.fromJson({
        'missionType': 'THEORY',
        'meta': {
          'missionTitle': 'Business Morning Mission',
          'subject': 'Business',
          'taskCodes': ['P1'],
        },
        'evidence': {'questions': List.generate(5, (_) => <String, dynamic>{})},
      });
      final html = const TeacherResultReportHtmlBuilder().build(
        studentName: 'Student',
        summaryLabel: 'All results',
        entries: [
          TeacherResultReportEntry(result: result, resultPackage: package),
        ],
      );
      expect(html, contains('P1 Theory Q5'));
      expect(html, isNot(contains('Business Morning Mission')));
      expect(package.meta.missionTitle, 'Business Morning Mission');
    },
  );

  testWidgets(
    'same-count types stay distinct and unsequenced Q10 is Objective',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentMissionPickerSheet(
              missions: [
                MissionPayload.fromJson(missionJson('QUESTIONS', 5)),
                MissionPayload.fromJson(missionJson('THEORY', 5)),
                MissionPayload.fromJson(missionJson('QUESTIONS', 10)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('P1 Objective Q5'), findsOneWidget);
      expect(find.text('P1 Theory Q5'), findsOneWidget);
      expect(find.text('P1 Objective Q10'), findsOneWidget);
      expect(find.text('Assessment A'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('student-mission-type-filters')),
          matching: find.text('Theory'),
        ),
      );
      await tester.pump();
      expect(find.text('P1 Theory Q5'), findsOneWidget);
      expect(find.text('P1 Objective Q5'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
