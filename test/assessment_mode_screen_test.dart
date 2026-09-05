/**
 * WHAT:
 * Verifies the optional second-assessment task-code availability policy.
 * WHY:
 * One assessment must remain a valid state, while only a third assessment is
 * blocked for the same task code and legacy over-counts remain safely locked.
 * HOW:
 * Exercise the count helpers for every boundary and render the real assessment
 * mode chips to verify selectability, independence, and teacher-facing copy.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/features/teacher/presentation/assessment_mode_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';

void main() {
  test('P1 count 0 is selectable', () {
    expect(assessmentTaskCodeIsLocked(const {}, 'P1'), isFalse);
  });

  test('P1 count 1 remains selectable', () {
    expect(assessmentTaskCodeIsLocked(const {'P1': 1}, 'P1'), isFalse);
  });

  test('P1 count 2 is locked', () {
    expect(assessmentTaskCodeIsLocked(const {'P1': 2}, 'P1'), isTrue);
  });

  test('P1 legacy count 3 is locked without changing the count', () {
    final counts = <String, int>{'P1': 3};

    expect(assessmentTaskCodeIsLocked(counts, 'P1'), isTrue);
    expect(counts, const {'P1': 3});
  });

  test('P1 count 1 and P2 count 0 are both selectable', () {
    const counts = {'P1': 1, 'P2': 0};

    expect(assessmentTaskCodeIsLocked(counts, 'P1'), isFalse);
    expect(assessmentTaskCodeIsLocked(counts, 'P2'), isFalse);
  });

  test('P1 count 2 locks only P1 while P2 stays selectable', () {
    const counts = {'P1': 2, 'P2': 0};

    expect(assessmentTaskCodeIsLocked(counts, 'P1'), isTrue);
    expect(assessmentTaskCodeIsLocked(counts, 'P2'), isFalse);
  });

  test('one-assessment copy says the second assessment is optional', () {
    final message = assessmentTaskCodeAvailabilityMessage('P1', 1);

    expect(
      message,
      'P1 already has one assessment. You can create one optional second assessment.',
    );
    expect(message.toLowerCase(), isNot(contains('required')));
  });

  test('two-assessment copy does not imply another assessment is required', () {
    final message = assessmentTaskCodeAvailabilityMessage('P1', 2);

    expect(message, 'P1 already has two assessments.');
    expect(message.toLowerCase(), isNot(contains('required')));
  });

  test('legacy count copy reports the safe existing-count state', () {
    expect(
      assessmentTaskCodeAvailabilityMessage('P1', 3),
      'P1 already has 3 assessments. No more can be created.',
    );
  });

  testWidgets('real task chips allow one assessment and lock only at two', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentModeScreen(
          studentName: 'Student One',
          subjectName: 'Business',
          sessionType: 'morning',
          targetDateLabel: 'Today',
          taskCodeOptions: const ['P1', 'P2'],
          initialTaskCodes: const [],
          timetableEntries: const <TodaySchedule>[],
          initialTargetDate: DateTime(2026, 9, 5),
          currentTeacherId: 'teacher-1',
          authToken: 'teacher-token',
          subjectId: 'subject-1',
          studentId: 'student-1',
          assessmentDraftCounts: const {'P1': 1, 'P2': 2},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final p1InkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text('P1'), matching: find.byType(InkWell)),
    );
    final p2InkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text('P2 🔒'), matching: find.byType(InkWell)),
    );

    expect(p1InkWell.onTap, isNotNull);
    expect(p2InkWell.onTap, isNull);
    expect(
      find.text(
        'P1 already has one assessment. You can create one optional second assessment.',
      ),
      findsOneWidget,
    );
    expect(find.text('P2 already has two assessments.'), findsOneWidget);
  });
}
