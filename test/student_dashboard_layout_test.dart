/**
 * WHAT: Verifies the compact student dashboard and permanent session cards.
 * WHY: Layout changes must preserve reports, mission selection, helper actions,
 * XP values and distinct certification states at every screen size.
 * HOW: Pump the real dashboard with synthetic API fixtures and exercise its
 * existing entry points without performing production account operations.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_mission_app/core/theme/app_theme.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/student/presentation/student_dashboard_screen.dart';
import 'package:focus_mission_app/features/student/presentation/student_subject_report_screen.dart';
import 'package:focus_mission_app/features/student/presentation/student_result_report_screen.dart';
import 'package:focus_mission_app/features/student/presentation/flexible_learning_helper_sheet.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';

const _session = AuthSession(
  token: 'synthetic-token',
  user: AppUser(
    id: 'student',
    name: 'Student Example',
    role: 'student',
    xp: 554,
    streak: 1,
  ),
);

class _StudentApi extends FocusMissionApi {
  final bool scheduled;
  bool hasMissions = false;
  List<Map<String, dynamic>> assignments = [];
  String? requestedMission;
  bool hasResult = false;
  bool hasPapers = false;
  String? requestedSession;
  String? requestedSubject;
  String? requestedResult;
  _StudentApi({this.scheduled = false});

  TodaySchedule get schedule => TodaySchedule.fromJson({
    'day': 'Monday',
    'room': 'Room 2',
    'morningMission': {'id': 'art', 'name': 'Art'},
    'afternoonMission': {'id': 'english', 'name': 'English'},
  });

  @override
  Future<StudentDashboardData> fetchStudentDashboard({
    required String token,
    required String studentId,
  }) async {
    expect(token, _session.token);
    expect(studentId, _session.user.id);
    return StudentDashboardData.fromJson({
      'student': {
        'id': 'student',
        'name': 'Student Example',
        'role': 'student',
        'xp': 554,
        'streak': 1,
        'daysSinceFirstLogin': 200,
      },
      if (scheduled)
        'today': {
          'day': schedule.day,
          'room': schedule.room,
          'morningMission': {'id': 'art', 'name': 'Art'},
          'afternoonMission': {'id': 'english', 'name': 'English'},
        },
      'dailyXp': {
        'dateKey': '2026-09-27',
        'totalXp': 20,
        'totalXpCap': 200,
        'dailyLoginXp': 20,
      },
      'assignedMissions': assignments,
      'recentSessions': [
        {
          'subjectName': 'Art',
          'focusScore': 80,
          'sessionType': 'morning',
          'completedQuestions': 5,
        },
        {
          'subjectName': 'Sport',
          'focusScore': 100,
          'sessionType': 'afternoon',
          'completedQuestions': 10,
        },
      ],
      'subjectProgress': [
        for (final name in ['Art', 'English', 'Sport'])
          {
            'subjectId': name.toLowerCase(),
            'subjectName': name,
            'completionPercentage': 25,
            'averageScore': 75,
          },
      ],
      if (hasPapers)
        'todayStandalonePapers': [
          {
            'id': 'test',
            'paperKind': 'TEST',
            'title': 'Assigned test',
            'status': 'published',
            'durationMinutes': 20,
            'sessionType': 'morning',
          },
          {
            'id': 'exam',
            'paperKind': 'EXAM',
            'title': 'Completed exam',
            'status': 'published',
            'latestSession': {
              'status': 'submitted',
              'resultPackageId': 'paper-result',
            },
          },
        ],
      'subjectCertification': [
        {
          'subjectId': 'art',
          'subjectName': 'Art',
          'certificationEnabled': true,
          'requiredTaskCodes': ['P1', 'P2'],
          'passedTaskCodes': ['P1'],
          'remainingTaskCodes': ['P2'],
        },
        {
          'subjectId': 'sport',
          'subjectName': 'Sport',
          'certificationEnabled': true,
          'certificateUnlocked': true,
          'requiredTaskCodes': ['P1'],
          'passedTaskCodes': ['P1'],
        },
      ],
    });
  }

  @override
  Future<List<TodaySchedule>> fetchStudentTimetable({
    required String token,
    required String studentId,
  }) async => scheduled ? [schedule] : [];

  @override
  Future<List<MissionPayload>> fetchStudentAssignedMissions({
    required String token,
    required String studentId,
    required String subjectId,
    required String sessionType,
  }) async {
    expect(token, _session.token);
    expect(studentId, 'student');
    requestedSubject = subjectId;
    requestedSession = sessionType;
    return hasMissions
        ? [
            MissionPayload.fromJson({
              'id': 'mission',
              'title': 'Assigned art mission',
              'subject': {'id': 'art', 'name': 'Art'},
              'draftFormat': 'QUESTIONS',
              'sessionType': sessionType,
              'status': 'published',
              'availableOnDate': '2026-09-27',
              'questionCount': 5,
            }),
          ]
        : [];
  }

  @override
  Future<StartedMission> startSession({
    required String token,
    required String studentId,
    required String subjectId,
    required String sessionType,
    String? missionId,
  }) {
    requestedMission = missionId;
    return Completer<StartedMission>().future;
  }

  @override
  Future<StudentSubjectReportData> fetchStudentSubjectReport({
    required String token,
    required String studentId,
    required String subjectId,
  }) async {
    requestedSubject = subjectId;
    return StudentSubjectReportData.fromJson({
      'subject': {'id': subjectId, 'name': subjectId},
      'certification': {},
      'missionHistory': hasResult
          ? [
              {'resultPackageId': 'saved-result'},
            ]
          : [],
    });
  }

  @override
  Future<ResultPackageData> fetchStudentResultReport({
    required String token,
    required String resultPackageId,
  }) {
    requestedResult = resultPackageId;
    return Completer<ResultPackageData>().future;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  double width = 1440,
  _StudentApi? api,
}) async {
  SharedPreferences.setMockInitialValues({
    'shown_student_dashboard_welcome_keys_v1': ['student:2026-09-27'],
  });
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: StudentDashboardScreen(
        session: _session,
        api: api ?? _StudentApi(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('permanent sessions and subject actions fit width $width', (
      tester,
    ) async {
      await _pump(tester, width: width);
      expect(tester.takeException(), isNull);
      expect(find.text('Morning Mission'), findsOneWidget);
      expect(find.text('Afternoon Mission'), findsOneWidget);
      expect(find.text('No mission assigned yet'), findsNWidgets(2));
      expect(find.text('Start Mission'), findsNothing);
      expect(find.text('View subject report'), findsNWidgets(3));
      expect(find.text('Open latest result'), findsNWidgets(3));
      expect(find.text('Helper'), findsOneWidget);
      final morning = tester.getTopLeft(find.text('Morning Mission'));
      final afternoon = tester.getTopLeft(find.text('Afternoon Mission'));
      if (width >= 768) {
        expect(afternoon.dy, morning.dy);
        expect(afternoon.dx, greaterThan(morning.dx));
      } else {
        expect(afternoon.dx, morning.dx);
        expect(afternoon.dy, greaterThan(morning.dy));
      }
      final first = tester.getTopLeft(find.text('Art').first);
      final second = tester.getTopLeft(find.text('English').first);
      if (width >= 768) {
        expect(second.dy, first.dy);
        expect(second.dx, greaterThan(first.dx));
      } else {
        expect(second.dy, greaterThan(first.dy));
      }
    });
  }

  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('persistent assignments and task-focus panel at $width', (
      tester,
    ) async {
      final api = _StudentApi()
        ..assignments = [
          for (final state in ['available', 'completed', 'redo_requested'])
            {
              'id': state,
              'title': 'Business $state',
              'subject': {'id': 'business', 'name': 'Business'},
              'taskCodes': ['P3'],
              'sessionType': 'afternoon',
              'availableOnDate': '2026-09-21',
              'availableOnDay': 'Monday',
              'assignmentStatus': state,
              'assignmentAttempt': state == 'redo_requested' ? 2 : 1,
              if (state == 'completed')
                'latestResultPackageId': 'previous-result',
              if (state == 'redo_requested') 'redoOfMissionId': 'completed',
            },
        ];
      await _pump(tester, width: width, api: api);
      expect(find.text('Morning Mission'), findsOneWidget);
      expect(find.text('Afternoon Mission'), findsOneWidget);
      expect(find.text('Business completed'), findsNothing);
      expect(find.text('Business available'), findsOneWidget);
      expect(find.text('Business redo_requested'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(ActionChip, 'P3'));
      await tester.tap(find.widgetWithText(ActionChip, 'P3'));
      await tester.pumpAndSettle();
      expect(find.text('Business · P3'), findsWidgets);
      expect(find.text('Completed · Locked · Attempt 1'), findsOneWidget);
      expect(find.text('View result'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('View result'));
      await tester.tap(find.text('View result'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(api.requestedResult, 'previous-result');
      expect(api.requestedMission, isNull);
    });
  }

  testWidgets(
    'available assignment starts its existing mission ID on a weekend',
    (tester) async {
      final api = _StudentApi()
        ..assignments = [
          {
            'id': 'old-monday-mission',
            'title': 'Business P3',
            'taskCodes': ['P3'],
            'subject': {'id': 'business', 'name': 'Business'},
            'sessionType': 'afternoon',
            'assignmentStatus': 'available',
            'availableOnDate': '2026-09-21',
          },
        ];
      await _pump(tester, api: api);
      await tester.ensureVisible(find.text('Start mission'));
      await tester.tap(find.text('Start mission'));
      await tester.pump();
      expect(api.requestedMission, 'old-monday-mission');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('XP, focus and certification states retain their data', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('XP: 554 / 200'), findsOneWidget);
    expect(find.text('20 / 200 XP'), findsOneWidget);
    expect(find.text('Daily bonus 20/20'), findsOneWidget);
    expect(find.text('Performance 0/100'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('Still needed: P2'), findsOneWidget);
    expect(find.text('Not active'), findsOneWidget);
    expect(find.text('Certificate unlocked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scheduled sessions retain actions when assignments are empty', (
    tester,
  ) async {
    final api = _StudentApi(scheduled: true);
    await _pump(tester, api: api);
    expect(find.text('Start Mission'), findsNWidgets(2));
    await tester.ensureVisible(find.text('Start Mission').last);
    await tester.tap(find.text('Start Mission').last);
    await tester.pumpAndSettle();
    expect(api.requestedSubject, 'english');
    expect(api.requestedSession, 'afternoon');
    expect(
      find.text(
        'No unfinished missions for this lesson today. Check Available Missions for earlier work.',
      ),
      findsOneWidget,
    );
    expect(find.text('Morning Mission'), findsOneWidget);
    expect(find.text('Afternoon Mission'), findsOneWidget);
  });

  testWidgets('mission action opens existing assigned mission picker', (
    tester,
  ) async {
    final api = _StudentApi(scheduled: true)..hasMissions = true;
    await _pump(tester, api: api);
    await tester.ensureVisible(find.text('Start Mission').first);
    await tester.tap(find.text('Start Mission').first);
    await tester.pumpAndSettle();
    expect(api.requestedSubject, 'art');
    expect(api.requestedSession, 'morning');
    expect(find.byType(StudentMissionPickerSheet), findsOneWidget);
    expect(find.text('Assigned art mission'), findsOneWidget);
  });

  testWidgets('both subject buttons retain report and latest-result routes', (
    tester,
  ) async {
    final api = _StudentApi()..hasResult = true;
    await _pump(tester, api: api);
    await tester.ensureVisible(find.text('View subject report').first);
    await tester.tap(find.text('View subject report').first);
    await tester.pumpAndSettle();
    expect(find.byType(StudentSubjectReportScreen), findsOneWidget);
    expect(api.requestedSubject, 'art');
    Navigator.of(tester.element(find.byType(StudentSubjectReportScreen))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open latest result').first);
    await tester.tap(find.text('Open latest result').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(StudentResultReportScreen), findsOneWidget);
    expect(api.requestedResult, 'saved-result');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Helper keeps its existing sheet on mobile', (tester) async {
    await _pump(tester, width: 390);
    await tester.tap(find.text('Helper'));
    await tester.pumpAndSettle();
    expect(find.byType(FlexibleLearningHelperSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('paper and assessment result actions remain available', (
    tester,
  ) async {
    final api = _StudentApi()..hasPapers = true;
    await _pump(tester, api: api);
    expect(find.text('Start Test'), findsOneWidget);
    expect(find.text('View result'), findsOneWidget);
    await tester.ensureVisible(find.text('View result'));
    await tester.tap(find.text('View result'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(api.requestedResult, 'paper-result');
    expect(find.byType(StudentResultReportScreen), findsOneWidget);
  });

  testWidgets('latest result keeps its empty-history feedback', (tester) async {
    await _pump(tester);
    await tester.ensureVisible(find.text('Open latest result').first);
    await tester.tap(find.text('Open latest result').first);
    await tester.pumpAndSettle();
    expect(
      find.text('No completed results are saved for Art yet.'),
      findsOneWidget,
    );
  });
}
