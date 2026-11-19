/**
 * WHAT: Checks saved-result task/type filtering and A/B metadata retention.
 * WHY: Renamed assessments and mixed result kinds must remain discoverable
 * without changing evidence or losing existing subject/date constraints.
 * HOW: Parse synthetic API records, compose scoped lists and exercise the
 * shared filter chips at narrow and wide viewport sizes.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:focus_mission_app/shared/widgets/result_history_filter_bar.dart';

ResultHistoryItem result(
  String id, {
  String format = 'QUESTIONS',
  String code = 'P1',
  String sequence = '',
  String kind = 'mission',
  String subject = 'Business',
  String date = '2026-11-18',
}) => ResultHistoryItem.fromJson({
  'id': id,
  'missionId': 'mission-$id',
  'resultPackageId': 'result-$id',
  'resultKind': kind,
  'title': 'Teacher edited title',
  'draftFormat': format,
  'questionCount': 10,
  'taskCodes': [code],
  'assessmentSequenceByTaskCode': {if (sequence.isNotEmpty) code: sequence},
  'subject': {'id': subject, 'name': subject},
  'availableOnDate': date,
});

void main() {
  test(
    'A/B metadata survives parsing and conversion despite title changes',
    () {
      final b = result('b', sequence: 'B');
      expect(b.assessmentSequenceByTaskCode, {'P1': 'B'});
      expect(b.toMissionContext().assessmentSequenceByTaskCode, {'P1': 'B'});
      expect(resultHistoryType(b), ResultHistoryTypeFilter.assessmentB);
      expect(
        resultHistoryType(result('a', sequence: 'A')),
        ResultHistoryTypeFilter.assessmentA,
      );
      expect(
        resultHistoryType(result('objective')),
        ResultHistoryTypeFilter.objective,
      );
      expect(
        resultHistoryType(
          result('paper', kind: 'paper_assessment', sequence: 'A'),
        ),
        ResultHistoryTypeFilter.paper,
      );
    },
  );

  test(
    'task/type filters retain subject/date scope and never mutate history',
    () {
      final history = [
        result('a', sequence: 'A'),
        result('b', sequence: 'B'),
        result('p2', code: 'P2'),
        result('sport', subject: 'Sport', sequence: 'A'),
        result('older', date: '2026-11-17', sequence: 'A'),
      ];
      final scoped = history
          .where(
            (item) =>
                item.subject?.name == 'Business' &&
                item.availableOnDate == '2026-11-18',
          )
          .toList();
      expect(
        filterResultHistory(
          scoped,
          taskCode: 'p1',
          type: ResultHistoryTypeFilter.assessmentA,
        ).map((item) => item.id),
        ['result-a'],
      );
      expect(
        filterResultHistory(
          scoped,
          taskCode: 'P2',
          type: ResultHistoryTypeFilter.assessmentB,
        ),
        isEmpty,
      );
      expect(
        filterResultHistory(
          history,
          taskCode: 'All',
          type: ResultHistoryTypeFilter.all,
        ),
        history,
      );
      expect(history.length, 5);
    },
  );

  for (final width in [390.0, 1200.0]) {
    testWidgets('result filters compose with counts at $width pixels', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var task = 'All';
      var type = ResultHistoryTypeFilter.all;
      final history = [
        result('a', sequence: 'A'),
        result('b', sequence: 'B'),
        result('p2', code: 'P2', format: 'THEORY'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => Column(
                  children: [
                    ResultHistoryFilterBar(
                      results: history,
                      selectedTaskCode: task,
                      selectedType: type,
                      onTaskCodeSelected: (value) =>
                          setState(() => task = value),
                      onTypeSelected: (value) => setState(() => type = value),
                    ),
                    ...filterResultHistory(
                      history,
                      taskCode: task,
                      type: type,
                    ).map((item) => Text(item.id)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('result_task_filter_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('result_type_filter_assessmentB')));
      await tester.pump();
      expect(find.text('result-b'), findsOneWidget);
      expect(find.text('result-a'), findsNothing);
      expect(find.text('result-p2'), findsNothing);
      expect(find.text('Assessment B 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('result_task_filter_p2')));
      await tester.pump();
      expect(find.text('result-b'), findsNothing);
      expect(find.text('Assessment B 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
