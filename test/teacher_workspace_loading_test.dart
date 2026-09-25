/**
 * WHAT:
 * Verifies the teacher workspace two-stage loading and parallel API batches.
 * WHY:
 * Teachers need the selected learner and timetable quickly, while delayed
 * secondary responses must never overwrite a newly selected learner.
 * HOW:
 * Use delayed HTTP fixtures to prove dependency waves, then pump the real
 * teacher screen with controllable supplemental responses.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/theme/app_theme.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/teacher/presentation/teacher_session_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _session = AuthSession(
  token: 'synthetic-token',
  user: AppUser(
    id: 'teacher-1',
    name: 'Synthetic Teacher',
    role: 'teacher',
    subjectSpecialty: 'Business',
  ),
);

const _students = <StudentSummary>[
  StudentSummary(
    id: 'student-a',
    name: 'Student Alpha',
    xp: 10,
    streak: 1,
    yearGroup: 'Year 10',
  ),
  StudentSummary(
    id: 'student-b',
    name: 'Student Beta',
    xp: 20,
    streak: 2,
    yearGroup: 'Year 11',
  ),
];

const _subjects = <SubjectSummary>[
  SubjectSummary(id: 'business', name: 'Business'),
];

StudentDashboardData _dashboardFor(StudentSummary student) {
  return StudentDashboardData.fromJson(<String, dynamic>{
    'student': <String, dynamic>{
      'id': student.id,
      'name': student.name,
      'role': 'student',
      'xp': student.xp,
      'streak': student.streak,
      'yearGroup': student.yearGroup,
    },
    'recentSessions': const <dynamic>[],
    'dailyXp': const <String, dynamic>{},
    'subjectProgress': const <dynamic>[],
    'subjectCertification': const <dynamic>[],
    'todayStandalonePapers': const <dynamic>[],
  });
}

TeacherWorkspaceData _essentialWorkspace(String requestedStudentId) {
  final selected = _students.firstWhere(
    (student) => student.id == requestedStudentId,
    orElse: () => _students.first,
  );
  return TeacherWorkspaceData(
    session: _session,
    students: _students,
    teacherSubjects: _subjects,
    selectedStudent: selected,
    selectedDashboard: _dashboardFor(selected),
    timetable: const <TodaySchedule>[],
    criteria: const <CriterionOverview>[],
    draftMissions: const <MissionPayload>[],
    recentMissions: const <MissionPayload>[],
    studentResults: const <ResultHistoryItem>[],
    notificationInbox: const NotificationInboxData(
      unreadCount: 0,
      notifications: <AppNotification>[],
    ),
    targets: const <TargetSummary>[],
  );
}

TeacherWorkspaceSupplementalData _supplementalFor(
  String studentId,
  String message,
) {
  return TeacherWorkspaceSupplementalData(
    criteria: const <CriterionOverview>[],
    draftMissions: const <MissionPayload>[],
    recentMissions: const <MissionPayload>[],
    studentResults: const <ResultHistoryItem>[],
    notificationInbox: NotificationInboxData(
      unreadCount: 1,
      notifications: <AppNotification>[
        AppNotification(
          id: 'notification-$studentId',
          type: 'criterion_submitted',
          title: message,
          message: message,
          isRead: false,
          studentId: studentId,
        ),
      ],
    ),
    targets: const <TargetSummary>[],
  );
}

MissionPayload _draftMission({
  required String id,
  required String title,
  required String taskCode,
  String draftFormat = 'QUESTIONS',
}) {
  return MissionPayload.fromJson(<String, dynamic>{
    'id': id,
    'title': title,
    'draftFormat': draftFormat,
    'questionCount': 5,
    'taskCodes': <String>[taskCode],
    'status': 'draft',
    'subject': const <String, dynamic>{'id': 'business', 'name': 'Business'},
    'availableOnDate': '2026-09-25',
  });
}

TeacherWorkspaceSupplementalData _supplementalWithDraftMissions() {
  return TeacherWorkspaceSupplementalData(
    criteria: const <CriterionOverview>[],
    draftMissions: <MissionPayload>[
      _draftMission(id: 'draft-p1', title: 'P1 Draft', taskCode: 'P1'),
      _draftMission(id: 'draft-p2', title: 'P2 Draft', taskCode: 'P2'),
      _draftMission(
        id: 'draft-m1',
        title: 'M1 Draft',
        taskCode: 'M1',
        draftFormat: 'THEORY',
      ),
    ],
    recentMissions: const <MissionPayload>[],
    studentResults: const <ResultHistoryItem>[],
    notificationInbox: const NotificationInboxData(
      unreadCount: 0,
      notifications: <AppNotification>[],
    ),
    targets: const <TargetSummary>[],
  );
}

Map<String, dynamic> _responseForPath(String path) {
  if (path.endsWith('/teacher/students')) {
    return <String, dynamic>{
      'students': _students
          .map(
            (student) => <String, dynamic>{
              'id': student.id,
              'name': student.name,
              'xp': student.xp,
              'streak': student.streak,
              'yearGroup': student.yearGroup,
            },
          )
          .toList(growable: false),
    };
  }
  if (path.endsWith('/teacher/subjects')) {
    return <String, dynamic>{
      'subjects': const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'business', 'name': 'Business'},
      ],
    };
  }
  if (path.contains('/student/dashboard/')) {
    final student = path.endsWith('student-b') ? _students[1] : _students[0];
    return <String, dynamic>{
      'student': <String, dynamic>{
        'id': student.id,
        'name': student.name,
        'role': 'student',
      },
      'recentSessions': const <dynamic>[],
      'dailyXp': const <String, dynamic>{},
      'subjectProgress': const <dynamic>[],
      'subjectCertification': const <dynamic>[],
      'todayStandalonePapers': const <dynamic>[],
    };
  }
  if (path.contains('/student/timetable/')) {
    return <String, dynamic>{'timetable': const <dynamic>[]};
  }
  if (path.contains('/criterion/student/')) {
    return <String, dynamic>{
      'student': const <String, dynamic>{
        'id': 'student-b',
        'name': 'Student Beta',
      },
      'criteria': const <dynamic>[],
    };
  }
  if (path.endsWith('/notifications')) {
    return <String, dynamic>{
      'unreadCount': 0,
      'notifications': const <dynamic>[],
    };
  }
  if (path.contains('/teacher/missions/drafts/') ||
      path.contains('/teacher/missions/recent/')) {
    return <String, dynamic>{'missions': const <dynamic>[]};
  }
  if (path.contains('/teacher/students/') && path.endsWith('/results')) {
    return <String, dynamic>{'results': const <dynamic>[]};
  }
  if (path.contains('/mentor/overview/')) {
    return <String, dynamic>{
      'student': const <String, dynamic>{
        'id': 'student-b',
        'name': 'Student Beta',
      },
      'metrics': const <String, dynamic>{},
      'targets': const <dynamic>[],
      'recentSessions': const <dynamic>[],
    };
  }
  throw StateError('Unexpected request path: $path');
}

class _ControlledTeacherWorkspaceApi extends FocusMissionApi {
  _ControlledTeacherWorkspaceApi();

  final Map<String, Completer<TeacherWorkspaceSupplementalData>>
  supplementalByStudent =
      <String, Completer<TeacherWorkspaceSupplementalData>>{};

  @override
  Future<TeacherWorkspaceData> loadTeacherWorkspace({
    required AuthSession session,
    String? selectedStudentId,
    String dateKey = '',
    bool includeSupplementalData = true,
  }) async {
    return _essentialWorkspace((selectedStudentId ?? '').trim());
  }

  @override
  Future<TeacherWorkspaceSupplementalData> loadTeacherWorkspaceSupplemental({
    required AuthSession session,
    required String studentId,
    String dateKey = '',
  }) {
    return supplementalByStudent
        .putIfAbsent(studentId, Completer<TeacherWorkspaceSupplementalData>.new)
        .future;
  }
}

Future<void> _pumpTeacherScreen(
  WidgetTester tester,
  FocusMissionApi api,
) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: TeacherSessionScreen(session: _session, api: api),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  test('workspace requests run in two parallel dependency waves', () async {
    final paths = <String>[];
    final api = FocusMissionApi(
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.headers['authorization'], 'Bearer synthetic-token');
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return http.Response(
          jsonEncode(_responseForPath(request.url.path)),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    final stopwatch = Stopwatch()..start();

    final workspace = await api.loadTeacherWorkspace(
      session: _session,
      selectedStudentId: 'student-b',
      dateKey: '2026-09-24',
    );
    stopwatch.stop();

    expect(workspace.selectedStudent.id, 'student-b');
    expect(paths, hasLength(10));
    expect(
      stopwatch.elapsed,
      lessThan(const Duration(milliseconds: 500)),
      reason: 'Ten 80 ms reads should complete as two dependency waves.',
    );
  });

  test(
    'essential workspace completes without requesting secondary panels',
    () async {
      final paths = <String>[];
      final api = FocusMissionApi(
        client: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode(_responseForPath(request.url.path)),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final workspace = await api.loadTeacherWorkspace(
        session: _session,
        selectedStudentId: 'student-a',
        includeSupplementalData: false,
      );

      expect(workspace.selectedStudent.id, 'student-a');
      expect(paths, hasLength(4));
      expect(paths.where((path) => path.contains('/results')), isEmpty);
      expect(paths.where((path) => path.endsWith('/notifications')), isEmpty);
      expect(workspace.studentResults, isEmpty);
    },
  );

  testWidgets('core teacher controls render before supplemental data', (
    tester,
  ) async {
    final api = _ControlledTeacherWorkspaceApi();
    await _pumpTeacherScreen(tester, api);

    expect(find.textContaining('Student Alpha · 10 XP'), findsOneWidget);
    expect(find.text('Switch student'), findsOneWidget);
    expect(
      find.text(
        'Workspace ready. Loading reviews and history in the background...',
      ),
      findsOneWidget,
    );

    api.supplementalByStudent['student-a']!.complete(
      _supplementalFor('student-a', 'Alpha review ready'),
    );
    await tester.pump();

    expect(find.text('Alpha review ready'), findsWidgets);
    expect(find.textContaining('Loading reviews and history'), findsNothing);
  });

  testWidgets('Draft Missions filters by task focus without changing data', (
    tester,
  ) async {
    final api = _ControlledTeacherWorkspaceApi();
    await _pumpTeacherScreen(tester, api);
    api.supplementalByStudent['student-a']!.complete(
      _supplementalWithDraftMissions(),
    );
    await tester.pump();

    expect(find.byKey(const Key('draft_level_filter_all')), findsOneWidget);
    expect(find.byKey(const Key('draft_level_filter_p1')), findsOneWidget);
    expect(find.byKey(const Key('draft_level_filter_p2')), findsOneWidget);
    expect(find.byKey(const Key('draft_level_filter_p3')), findsOneWidget);
    expect(find.byKey(const Key('draft_level_filter_p4')), findsOneWidget);
    expect(find.byKey(const Key('draft_level_filter_m1')), findsOneWidget);
    expect(find.byKey(const Key('draft_level_filter_m2')), findsOneWidget);
    expect(find.byKey(const Key('draft_level_filter_m3')), findsOneWidget);
    expect(find.byKey(const Key('draft_filter_all')), findsOneWidget);
    expect(find.byKey(const Key('draft_filter_objective')), findsOneWidget);
    expect(find.byKey(const Key('draft_filter_theory')), findsOneWidget);
    expect(find.byKey(const Key('draft_filter_essay')), findsOneWidget);
    expect(find.byKey(const Key('draft_filter_assessmentA')), findsOneWidget);
    expect(find.text('P1 Draft'), findsOneWidget);
    expect(find.text('P2 Draft'), findsOneWidget);
    expect(find.text('M1 Draft'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('draft_level_filter_p2')));
    await tester.tap(find.byKey(const Key('draft_level_filter_p2')));
    await tester.pump();

    expect(find.text('P1 Draft'), findsNothing);
    expect(find.text('P2 Draft'), findsOneWidget);
    expect(find.text('M1 Draft'), findsNothing);
    expect(find.text('1 shown'), findsOneWidget);

    await tester.tap(find.byKey(const Key('draft_level_filter_all')));
    await tester.tap(find.byKey(const Key('draft_filter_theory')));
    await tester.pump();

    expect(find.text('P1 Draft'), findsNothing);
    expect(find.text('P2 Draft'), findsNothing);
    expect(find.text('M1 Draft'), findsOneWidget);
  });

  testWidgets('late old-student data cannot overwrite a new selection', (
    tester,
  ) async {
    final api = _ControlledTeacherWorkspaceApi();
    await _pumpTeacherScreen(tester, api);

    await tester.tap(find.text('Switch student'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.textContaining('Student Beta').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Student Beta · 20 XP'), findsOneWidget);
    api.supplementalByStudent['student-b']!.complete(
      _supplementalFor('student-b', 'Beta review ready'),
    );
    await tester.pump();
    expect(find.text('Beta review ready'), findsWidgets);

    api.supplementalByStudent['student-a']!.complete(
      _supplementalFor('student-a', 'Stale Alpha review'),
    );
    await tester.pump();

    expect(find.text('Beta review ready'), findsWidgets);
    expect(find.text('Stale Alpha review'), findsNothing);
  });

  testWidgets('supplemental failure keeps the core workspace usable', (
    tester,
  ) async {
    final api = _ControlledTeacherWorkspaceApi();
    await _pumpTeacherScreen(tester, api);
    api.supplementalByStudent['student-a']!.completeError(
      const FocusMissionApiException('Synthetic secondary failure.'),
    );
    await tester.pump();

    expect(find.textContaining('Student Alpha · 10 XP'), findsOneWidget);
    expect(find.text('Switch student'), findsOneWidget);
    expect(
      find.text(
        'The core workspace is ready. Some supporting panels could not load.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}
