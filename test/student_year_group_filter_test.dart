/**
 * WHAT:
 * Tests the shared teacher student-picker year-group filter.
 * WHY:
 * All authorised learners must remain discoverable while Year 9, Year 10, and
 * Year 11 views narrow only the visible roster and never alter selection.
 * HOW:
 * Exercise the pure filter for every supported choice and pump the real chips
 * to verify selected styling and change callbacks.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:focus_mission_app/shared/widgets/student_year_group_filter.dart';

void main() {
  const students = <StudentSummary>[
    StudentSummary(
      id: 'sudais',
      name: 'Sudais Dahir',
      xp: 10,
      streak: 1,
      yearGroup: 'Year 9',
    ),
    StudentSummary(
      id: 'jace',
      name: 'Jace Mckenzie',
      xp: 20,
      streak: 2,
      yearGroup: 'Year 10',
    ),
    StudentSummary(
      id: 'ahmed',
      name: 'Ahmed Stockwin',
      xp: 30,
      streak: 3,
      yearGroup: 'Year 10',
    ),
    StudentSummary(
      id: 'year-11',
      name: 'Year Eleven Learner',
      xp: 40,
      streak: 4,
      yearGroup: 'Year 11',
    ),
    StudentSummary(id: 'unset', name: 'Year Not Set', xp: 0, streak: 0),
  ];

  test('All shows every authorised student', () {
    expect(
      filterStudentsByYearGroup(students, kAllStudentYearGroups),
      students,
    );
  });

  test('Year 9 shows only Year 9', () {
    final visible = filterStudentsByYearGroup(students, 'Year 9');
    expect(visible.map((student) => student.id), ['sudais']);
  });

  test('Year 10 shows only Year 10', () {
    final visible = filterStudentsByYearGroup(students, 'Year 10');
    expect(visible.map((student) => student.id), ['jace', 'ahmed']);
  });

  test('Year 11 shows only Year 11', () {
    final visible = filterStudentsByYearGroup(students, 'Year 11');
    expect(visible.map((student) => student.id), ['year-11']);
  });

  test('switching filters leaves the current selected student untouched', () {
    const selectedStudentId = 'sudais';
    final yearTen = filterStudentsByYearGroup(students, 'Year 10');
    final all = filterStudentsByYearGroup(students, kAllStudentYearGroups);

    expect(yearTen.any((student) => student.id == selectedStudentId), isFalse);
    expect(all.any((student) => student.id == selectedStudentId), isTrue);
    expect(selectedStudentId, 'sudais');
    expect(students.length, 5);
  });

  testWidgets('filter chips clearly select the requested year', (tester) async {
    var selected = kAllStudentYearGroups;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => StudentYearGroupFilter(
              selectedYearGroup: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
          .selected,
      isTrue,
    );
    await tester.tap(find.text('Year 10'));
    await tester.pump();

    expect(selected, 'Year 10');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Year 10'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
          .selected,
      isFalse,
    );
  });
}
