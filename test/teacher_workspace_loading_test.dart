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
import 'package:focus_mission_app/features/teacher/presentation/standalone_paper_screen.dart';
import 'package:focus_mission_app/features/teacher/models/standalone_paper_models.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:focus_mission_app/shared/widgets/notification_panel.dart';
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

StudentDashboardData _dashboardFor(
  StudentSummary student, {
  List<Map<String, dynamic>> certifications = const [],
}) {
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
    'subjectCertification': certifications,
    'todayStandalonePapers': const <dynamic>[],
  });
}

TeacherWorkspaceData _essentialWorkspace(
  String requestedStudentId, {
  List<Map<String, dynamic>> certifications = const [],
  bool scheduled = false,
}) {
  final selected = _students.firstWhere(
    (student) => student.id == requestedStudentId,
    orElse: () => _students.first,
  );
  return TeacherWorkspaceData(
    session: _session,
    students: _students,
    teacherSubjects: _subjects,
    selectedStudent: selected,
    selectedDashboard: _dashboardFor(selected, certifications: certifications),
    timetable: scheduled
        ? [
            for (final day in [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday',
            ])
              TodaySchedule(
                day: day,
                room: 'Room 1',
                morningMission: _subjects.first,
                afternoonMission: _subjects.first,
                morningTeacher: const TeacherSummary(
                  id: 'teacher-1',
                  name: 'Synthetic Teacher',
                ),
                afternoonTeacher: const TeacherSummary(
                  id: 'teacher-1',
                  name: 'Synthetic Teacher',
                ),
              ),
          ]
        : const <TodaySchedule>[],
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
  _ControlledTeacherWorkspaceApi({
    this.certifications = const [],
    this.scheduled = false,
  });

  final bool scheduled;

  final List<Map<String, dynamic>> certifications;

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
    return _essentialWorkspace(
      (selectedStudentId ?? '').trim(),
      certifications: certifications,
      scheduled: scheduled,
    );
  }

  @override
  Future<List<SubjectCertificationSummary>> fetchTeacherStudentCertification({
    required String token,
    required String studentId,
  }) async => [];

  @override
  Future<List<StandalonePaperDraft>> fetchStandalonePapers({
    required String token,
    required String studentId,
    required String paperKind,
  }) async => [];

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
  for (final label in ['Objective', 'Theory', 'Essay']) {
    testWidgets('Create $label carries the selected lesson into its builder', (
      tester,
    ) async {
      final api = _ControlledTeacherWorkspaceApi(scheduled: true);
      await _pumpTeacherScreen(tester, api);
      api.supplementalByStudent['student-a']!.complete(
        _supplementalWithDraftMissions(),
      );
      await tester.pumpAndSettle();
      final button = find.text('Create $label');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Build $label Mission'), findsOneWidget);
      expect(find.text('Generate $label Draft'), findsOneWidget);
      expect(find.text('Student Alpha'), findsWidgets);
      expect(find.text('Business'), findsWidgets);
      expect(find.text('Change mission date'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final kind in ['Test', 'Exam']) {
    testWidgets('Create $kind still opens its dedicated paper workflow', (
      tester,
    ) async {
      final api = _ControlledTeacherWorkspaceApi(scheduled: true);
      await _pumpTeacherScreen(tester, api);
      api.supplementalByStudent['student-a']!.complete(
        _supplementalWithDraftMissions(),
      );
      await tester.pumpAndSettle();
      final button = find.text('Create $kind');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Continue with 1 student'), findsOneWidget);
      await tester.tap(find.text('Continue with 1 student'));
      await tester.pumpAndSettle();
      expect(
        find.byType(
          kind == 'Test' ? StandaloneTestScreen : StandaloneExamScreen,
        ),
        findsOneWidget,
      );
      expect(find.text('Build Objective Mission'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('quick-create toolbar wraps on phones and keeps Select drafts', (
    tester,
  ) async {
    final api = _ControlledTeacherWorkspaceApi(scheduled: true);
    await _pumpTeacherScreen(tester, api);
    api.supplementalByStudent['student-a']!.complete(
      _supplementalWithDraftMissions(),
    );
    await tester.pumpAndSettle();
    for (final label in [
      'Create Objective',
      'Create Theory',
      'Create Essay',
      'Create Test',
      'Create Exam',
      'Select drafts',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    final select = find.text('Select drafts');
    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pumpAndSettle();
    expect(find.text('Selecting drafts'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Exercise the actual toolbar independently of the timetable's layout.
    final toolbarFinder = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_DraftMissionToolbar',
    );
    final toolbar = tester.widget(toolbarFinder);
    for (final width in [320.0, 390.0, 768.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(padding: const EdgeInsets.all(16), child: toolbar),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Toolbar at $width px');
      for (final label in [
        'Create Objective',
        'Create Theory',
        'Create Essay',
        'Create Test',
        'Create Exam',
        'Selecting drafts',
      ]) {
        final bounds = tester.getRect(find.text(label));
        expect(bounds.left, greaterThanOrEqualTo(16));
        expect(bounds.right, lessThanOrEqualTo(width - 16));
      }
    }
  });

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

    expect(find.text('Student Alpha'), findsOneWidget);
    expect(find.text('Year 10 · 10 XP'), findsOneWidget);
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

  testWidgets('student context stays compact and wraps at narrow widths', (
    tester,
  ) async {
    final api = _ControlledTeacherWorkspaceApi();
    await _pumpTeacherScreen(tester, api);
    api.supplementalByStudent['student-a']!.complete(
      _supplementalFor('student-a', 'Ready'),
    );
    await tester.pump();

    final contextFinder = find.byKey(
      const Key('teacher_student_lesson_context'),
    );
    final contextCard = tester.widget(contextFinder);
    expect(tester.getSize(contextFinder).height, lessThan(260));
    expect(find.text('Selected Student'), findsNothing);
    expect(find.text('Student year group'), findsNothing);
    for (final label in [
      'Switch student',
      'Add student',
      'Open analytics',
      'Task Focus work',
      'Qualification Review',
      'Student Results',
      'Save',
    ]) {
      expect(
        find.descendant(of: contextFinder, matching: find.text(label)),
        findsOneWidget,
      );
    }

    for (final width in [320.0, 390.0, 768.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: contextCard,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Context at $width px');
      final bounds = tester.getRect(contextFinder);
      expect(bounds.right, lessThanOrEqualTo(width - 24));
      // Text wraps more at narrow widths; require every control to remain
      // within the card rather than imposing a fixed mobile height.
      expect(bounds.bottom, lessThanOrEqualTo(900));
      for (final label in [
        'Switch student',
        'Add student',
        'Open analytics',
        'Task Focus work',
        'Qualification Review',
        'Student Results',
        'Save',
      ]) {
        final button = tester.getRect(find.text(label));
        expect(button.right, lessThanOrEqualTo(bounds.right));
        expect(button.left, greaterThanOrEqualTo(bounds.left));
      }
    }
  });

  testWidgets('compact lower panels preserve certification evidence and wrap', (
    tester,
  ) async {
    final api = _ControlledTeacherWorkspaceApi(
      certifications: [
        {
          'subjectId': 'business',
          'subjectName': 'Business',
          'certificationLabel': 'Course Certification',
          'requiredTaskCodes': [
            'D1',
            'D2',
            'M1',
            'M2',
            'M3',
            'P1',
            'P2',
            'P3',
            'P4',
            'P5',
            'P6',
            'P7',
          ],
          'passedTaskCodes': ['P1'],
          'remainingTaskCodes': [
            'D1',
            'D2',
            'M1',
            'M2',
            'M3',
            'P2',
            'P3',
            'P4',
            'P5',
            'P6',
            'P7',
          ],
          'completionPercentage': 8,
          'averagePassedScorePercent': 80,
          'planVersion': 3,
          'planSource': 'teacher_plan',
          'planChangeReason': 'Lesson 3',
          'evidenceRows': [
            {'taskCode': 'P1', 'status': 'passed', 'bestScorePercent': 80},
            {'taskCode': 'P2', 'status': 'pending_review'},
          ],
        },
      ],
    );
    await _pumpTeacherScreen(tester, api);
    api.supplementalByStudent['student-a']!.complete(
      _supplementalWithDraftMissions(),
    );
    await tester.pump();
    expect(find.text('1/12 passed'), findsOneWidget);
    expect(find.text('P1 · 80%'), findsOneWidget);
    expect(find.text('P2 · Pending'), findsOneWidget);
    expect(find.text('Edit objectives'), findsOneWidget);
    expect(
      find.text(
        '8% complete · Average on passed focuses 80.0% · Plan v3 · Teacher-owned plan · Last changed Lesson 3',
      ),
      findsOneWidget,
    );
    final certification = find.byKey(const Key('teacher_certification'));
    await tester.tap(find.byKey(const Key('open_qualification_review')));
    await tester.pump();
    final review = find.byKey(const Key('teacher_qualification_review'));
    final inbox = find.byType(NotificationPanel);
    expect(tester.getSize(certification).height, lessThan(350));
    expect(tester.getSize(review).height, lessThan(150));
    expect(tester.getSize(inbox).height, lessThan(150));
    final panels = [
      tester.widget(certification),
      tester.widget(review),
      tester.widget(inbox),
    ];
    for (final width in [320.0, 390.0, 768.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: panels,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Lower panels at $width px',
      );
      expect(find.text('P1 · 80%'), findsOneWidget);
      expect(find.text('Edit objectives'), findsOneWidget);
      expect(find.text('All read'), findsOneWidget);
    }
  });

  testWidgets('compact inbox preserves notification content and tap identity', (
    tester,
  ) async {
    const notification = AppNotification(
      id: 'review-1',
      type: 'criterion_submitted',
      title: 'Review submitted Business criterion',
      message: 'Student work is ready for teacher review.',
      isRead: false,
      studentName: 'Student Alpha',
      criterionTitle: 'Business principles',
    );
    AppNotification? opened;
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: NotificationPanel(
              compact: true,
              title: 'Teacher Inbox',
              subtitle: 'Review submission alerts.',
              notifications: const [notification],
              unreadCount: 1,
              emptyMessage: 'No alerts.',
              onTapNotification: (value) => opened = value,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('1 unread'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Student Alpha'), findsOneWidget);
    expect(find.text('Business principles'), findsOneWidget);
    await tester.tap(find.text(notification.title));
    expect(opened, same(notification));
  });

  testWidgets('top utilities open on demand and reset when switching students', (
    tester,
  ) async {
    final api = _ControlledTeacherWorkspaceApi();
    await _pumpTeacherScreen(tester, api);
    final reviewAction = find.byKey(const Key('open_qualification_review'));
    final resultsAction = find.byKey(const Key('open_student_results'));
    final reviewPanel = find.byKey(const Key('teacher_qualification_review'));
    final resultsPanel = find.byKey(const Key('teacher_student_results'));
    expect(tester.widget<OutlinedButton>(reviewAction).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(resultsAction).onPressed, isNull);
    api.supplementalByStudent['student-a']!.complete(
      _supplementalWithDraftMissions(),
    );
    await tester.pump();
    expect(reviewPanel, findsNothing);
    expect(resultsPanel, findsNothing);

    await tester.tap(reviewAction);
    await tester.pump();
    expect(reviewPanel, findsOneWidget);
    expect(
      find.text("No criteria match this teacher's subject yet."),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close Qualification Review'));
    await tester.pump();
    expect(reviewPanel, findsNothing);

    await tester.tap(resultsAction);
    await tester.pump();
    expect(resultsPanel, findsOneWidget);
    expect(find.text('Upload Result'), findsOneWidget);
    expect(find.text('Download Day'), findsOneWidget);
    expect(find.text('Result date'), findsOneWidget);
    expect(
      find.text(
        'No saved results are available yet for this student in your subjects.',
      ),
      findsOneWidget,
    );
    await tester.tap(resultsAction);
    await tester.pump();
    expect(resultsPanel, findsNothing);
    await tester.tap(resultsAction);
    await tester.tap(reviewAction);
    await tester.pump();

    await tester.tap(find.text('Switch student'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.textContaining('Student Beta').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    api.supplementalByStudent['student-b']!.complete(
      _supplementalFor('student-b', 'Beta ready'),
    );
    await tester.pump();
    expect(reviewPanel, findsNothing);
    expect(resultsPanel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Student Results cards retain actions and adapt to the available width',
    (tester) async {
      final api = _ControlledTeacherWorkspaceApi();
      await _pumpTeacherScreen(tester, api);
      api.supplementalByStudent['student-a']!.complete(
        TeacherWorkspaceSupplementalData(
          criteria: const [],
          draftMissions: const [],
          recentMissions: const [],
          studentResults: List.generate(
            2,
            (index) => ResultHistoryItem.fromJson({
              'id': 'history-$index',
              'resultPackageId': 'result-$index',
              'missionId': 'mission-$index',
              'title': 'Assessment ${index + 1}',
              'draftFormat': 'QUESTIONS',
              'status': 'submitted',
              'sessionType': 'afternoon',
              'questionCount': 10,
              'scoreCorrect': 9,
              'scoreTotal': 10,
              'scorePercent': 90,
              'xpReward': 50,
              'xpEarned': 45,
              'taskCodes': ['P1'],
              'subject': {'id': 'business', 'name': 'Business'},
              'availableOnDate': '2026-09-21',
            }),
          ),
          notificationInbox: const NotificationInboxData(
            unreadCount: 0,
            notifications: [],
          ),
          targets: const [],
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open_student_results')));
      await tester.pump();
      expect(find.text('Upload Result'), findsOneWidget);
      expect(find.text('Download Day'), findsOneWidget);
      expect(find.text('View Result'), findsNWidgets(2));
      expect(find.text('Download Result'), findsNWidgets(2));
      expect(find.text('9/10 (90%) score · 45/50 XP'), findsNWidgets(2));
      expect(find.text('Task Focus: P1'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('Assessment 1')).dy,
        tester.getTopLeft(find.text('Assessment 2')).dy,
      );
      expect(
        tester.getTopLeft(find.text('Assessment 2')).dx,
        greaterThan(tester.getTopLeft(find.text('Assessment 1')).dx),
      );
      // Exercise the result panel independently of the timetable and assigned
      // mission headers, which have their own responsive-layout coverage.
      final resultsPanel = tester.widget(
        find.byKey(const Key('teacher_student_results')),
      );
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: resultsPanel,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('Assessment 2')).dy,
        greaterThan(tester.getTopLeft(find.text('Assessment 1')).dy),
      );
      expect(find.text('View Result'), findsNWidgets(2));
      expect(find.text('Download Result'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.text('Showing 1–1 of 1'), findsOneWidget);

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

    expect(find.text('Student Beta'), findsOneWidget);
    expect(find.text('Year 11 · 20 XP'), findsOneWidget);
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

    expect(find.text('Student Alpha'), findsOneWidget);
    expect(find.text('Year 10 · 10 XP'), findsOneWidget);
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
