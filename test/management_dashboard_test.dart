/**
 * WHAT: Checks the compact management dashboard and access to existing tools.
 * WHY: Summaries must remain readable across screen sizes without hiding data
 * or losing access to targets, results, and student controls.
 * HOW: Pump the real screen with synthetic API responses at desktop and mobile
 * sizes, then open the existing detail views from the summary actions.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/theme/app_theme.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/management/presentation/management_overview_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';

const _session = AuthSession(
  token: 'synthetic-token',
  user: AppUser(id: 'management', name: 'Management', role: 'management'),
);
const _student = StudentSummary(
  id: 'student',
  name: 'Synthetic Learner',
  yearGroup: 'Year 11',
  xp: 130,
  streak: 3,
);

class _DashboardApi extends FocusMissionApi {
  final bool empty;
  _DashboardApi({this.empty = false});

  @override
  Future<MentorWorkspaceData> loadMentorWorkspace({
    required AuthSession mentorSession,
    String? selectedStudentId,
    String dateKey = '',
  }) async => MentorWorkspaceData(
    session: _session,
    students: const [_student],
    selectedStudent: _student,
    overview: MentorOverviewData.fromJson({
      'student': {'id': _student.id, 'name': _student.name},
      'metrics': {'weeklyXp': 70, 'completedMissions': 36},
    }),
    timetable: const [],
    notificationInbox: const NotificationInboxData(
      unreadCount: 0,
      notifications: [],
    ),
  );

  @override
  Future<List<ResultHistoryItem>> fetchManagementStudentResults({
    required String token,
    required String studentId,
  }) async => empty
      ? []
      : [
          ResultHistoryItem.fromJson({
            'id': 'result',
            'title': 'Saved result example',
            'createdAt': '2026-09-25T12:00:00Z',
            'subject': {'id': 'business', 'name': 'Business'},
          }),
        ];

  @override
  Future<ManagementTargetHistory> fetchManagementStudentTargets({
    required String token,
    required String studentId,
    required String dateKey,
  }) async {
    final now = DateTime.now();
    var weekday = DateTime(now.year, now.month, 1);
    while (weekday.weekday > DateTime.friday) {
      weekday = weekday.add(const Duration(days: 1));
    }
    final date =
        '${weekday.year}-${weekday.month.toString().padLeft(2, '0')}-${weekday.day.toString().padLeft(2, '0')}';
    return ManagementTargetHistory.fromJson({
      'targets': empty
          ? []
          : [
              {
                'id': 'target',
                'title': 'Finish one daily mission',
                'status': 'pending',
                'difficulty': 'medium',
                'awardDateKey': date,
                'xpAwarded': 0,
              },
            ],
    });
  }

  @override
  Future<List<SubjectCertificationSummary>>
  fetchManagementStudentCertification({
    required String token,
    required String studentId,
  }) async => empty
      ? []
      : [
          SubjectCertificationSummary.fromJson({
            'subjectId': 'business',
            'subjectName': 'Business',
            'requiredTaskCodes': ['P1', 'P2'],
            'passedTaskCodes': ['P1'],
          }),
        ];
  @override
  Future<List<SubjectCertificationSettings>>
  fetchManagementCertificationSubjects({required String token}) async => [];
  @override
  Future<List<TeacherSummary>> fetchManagementTeachers({
    required String token,
  }) async => [];
  @override
  Future<List<StudentSummary>> fetchManagementStudents({
    required String token,
    String status = 'active',
  }) async => [];
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  bool empty = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1100);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: ManagementOverviewScreen(
        session: _session,
        api: _DashboardApi(empty: empty),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'desktop shows two-column summaries before opening detail tools',
    (tester) async {
      await _pump(tester, width: 1440);
      expect(tester.takeException(), isNull);
      expect(find.text('1 total · 1 pending · 0 XP'), findsOneWidget);
      expect(find.text('1/2 passed'), findsOneWidget);
      expect(find.text('1 saved results'), findsOneWidget);
      expect(find.text('Download target results'), findsNothing);
      expect(find.text('Download filtered results'), findsNothing);
      expect(find.text('Archive student'), findsOneWidget);
      final details = tester.getTopLeft(find.text('Student details'));
      final snapshot = tester.getTopLeft(find.text('Delivery Snapshot'));
      expect(snapshot.dy, details.dy);
      expect(snapshot.dx, greaterThan(details.dx));

      await tester.tap(find.byKey(const Key('management_view_targets')));
      await tester.pumpAndSettle();
      expect(find.text('Target date'), findsOneWidget);
      expect(find.text('Download target results'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        find.byKey(const Key('management_view_results')),
      );
      await tester.tap(find.byKey(const Key('management_view_results')));
      await tester.pumpAndSettle();
      expect(find.text('Result date'), findsOneWidget);
      expect(find.text('Download filtered results'), findsOneWidget);
      expect(find.text('Saved result example'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [390.0, 768.0]) {
    testWidgets('summaries stack without overflow at width $width', (
      tester,
    ) async {
      await _pump(tester, width: width);
      expect(tester.takeException(), isNull);
      final details = tester.getTopLeft(find.text('Student details'));
      final snapshot = tester.getTopLeft(find.text('Delivery Snapshot'));
      expect(snapshot.dx, details.dx);
      expect(snapshot.dy, greaterThan(details.dy));
      expect(find.text('Switch student'), findsOneWidget);
      expect(find.text('View archived'), findsOneWidget);
    });
  }

  testWidgets(
    'empty summaries offer existing tools without invented workflows',
    (tester) async {
      await _pump(tester, width: 1440, empty: true);
      expect(find.text('No targets recorded for this month.'), findsOneWidget);
      expect(
        find.text('No certification progress recorded yet.'),
        findsOneWidget,
      );
      expect(find.text('0 saved results'), findsOneWidget);
      expect(find.text('No management notifications yet.'), findsOneWidget);
      expect(find.text('View results & downloads'), findsOneWidget);
      expect(find.text('Upload result'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
