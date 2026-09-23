/**
 * WHAT:
 * Tests shared student year filtering and the management student picker.
 * WHY:
 * All authorised learners must remain discoverable while Year 9, Year 10, and
 * Year 11 views narrow only the visible roster and never alter selection.
 * HOW:
 * Exercise the pure filter, pump the real chips, and open the management modal
 * at desktop and mobile sizes to verify search, scrolling, and safe bounds.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/features/management/presentation/management_overview_screen.dart';
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
  const managementStudents = <StudentSummary>[
    StudentSummary(
      id: 'ahmed',
      name: 'Ahmed Stockwin',
      xp: 130,
      streak: 1,
      yearGroup: 'Year 11',
    ),
    StudentSummary(
      id: 'asia',
      name: 'Asia-Lei Waller',
      xp: 258,
      streak: 1,
      yearGroup: 'Year 11',
    ),
    StudentSummary(
      id: 'grace',
      name: 'Grace Wesson',
      xp: 50,
      streak: 0,
      yearGroup: 'Year 9',
    ),
    StudentSummary(
      id: 'jace',
      name: 'Jace Mckenzie',
      xp: 0,
      streak: 0,
      yearGroup: 'Year 10',
    ),
    StudentSummary(
      id: 'kerine',
      name: 'Kerine Ryan',
      xp: 111,
      streak: 1,
      yearGroup: 'Year 11',
    ),
    StudentSummary(
      id: 'luqman',
      name: 'Luqman Tariq',
      xp: 301,
      streak: 2,
      yearGroup: 'Year 10',
    ),
    StudentSummary(
      id: 'maria',
      name: 'Maria James',
      xp: 96,
      streak: 1,
      yearGroup: 'Year 9',
    ),
    StudentSummary(
      id: 'zara',
      name: 'Zara Wilson',
      xp: 72,
      streak: 0,
      yearGroup: 'Year 10',
    ),
  ];

  Future<void> openManagementPicker(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showManagementStudentPickerSheet(
                  context: context,
                  students: managementStudents,
                  selectedStudentId: 'ahmed',
                ),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
  }

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

  testWidgets('management picker search and year filters stay accessible', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openManagementPicker(tester, const Size(390, 700));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('management_student_search')), findsOneWidget);
    expect(find.text('8 of 8 students'), findsOneWidget);
    expect(find.byKey(const Key('management_student_list')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('management_student_search')),
      'Asia',
    );
    await tester.pump();
    expect(find.text('1 of 8 students'), findsOneWidget);
    expect(
      find.byKey(const Key('management_student_row_asia')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('management_student_row_ahmed')), findsNothing);

    await tester.tap(find.byKey(const Key('management_student_search_clear')));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Year 10'));
    await tester.pump();
    expect(find.text('3 of 8 students'), findsOneWidget);
    expect(
      find.byKey(const Key('management_student_row_jace')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('management_student_row_ahmed')), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('management_student_row_zara')),
      240,
      scrollable: find.descendant(
        of: find.byKey(const Key('management_student_list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.byKey(const Key('management_student_row_zara')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('management picker uses a tall bounded desktop sheet', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openManagementPicker(tester, const Size(1440, 900));

    final sheetSize = tester.getSize(find.byType(ManagementStudentPickerSheet));
    expect(sheetSize.height, greaterThan(650));
    expect(sheetSize.width, lessThanOrEqualTo(720));
    expect(find.text('Close student picker'), findsNothing);
    expect(find.byTooltip('Close student picker'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
