/**
 * WHAT:
 * Tests target-student schedule resolution and the Flutter mission-reuse API
 * contract.
 * WHY:
 * A cloned draft must use the target learner's own teacher-owned subject slot
 * and send explicit variation choices without copying the source schedule.
 * HOW:
 * Build slots from typed timetable fixtures and inspect a mocked HTTP request
 * to the backend reuse endpoint.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/teacher/presentation/mission_reuse_sheet.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const business = SubjectSummary(id: 'business', name: 'Business');
  const maths = SubjectSummary(id: 'maths', name: 'Maths');
  const teacher = TeacherSummary(id: 'teacher-1', name: 'Business Teacher');
  const otherTeacher = TeacherSummary(id: 'teacher-2', name: 'Other Teacher');

  MissionPayload sourceMission() => const MissionPayload(
    id: 'source-draft',
    title: 'Business Q8 Revision',
    teacherNote: '',
    sourceUnitText: 'Reviewed content',
    sourceRawText: 'Reviewed content',
    sourceFileName: '',
    sourceFileType: '',
    draftFormat: 'QUESTIONS',
    essayMode: '',
    draftJson: null,
    source: 'groq',
    status: 'draft',
    sessionType: 'morning',
    difficulty: 'medium',
    taskCodes: ['P1'],
    xpReward: 30,
    xpEarned: 0,
    questionCount: 8,
    scoreCorrect: 0,
    scoreTotal: 8,
    scorePercent: 0,
    latestResultPackageId: '',
    questions: [],
    subject: MissionSubject(id: 'business', name: 'Business'),
  );

  test(
    'reuse slots use the target timetable subject and teacher assignment',
    () {
      final slots = buildMissionReuseSlots(
        timetable: const [
          TodaySchedule(
            day: 'Monday',
            room: 'Room 1',
            morningMission: business,
            afternoonMission: business,
            morningTeacher: teacher,
            afternoonTeacher: otherTeacher,
          ),
        ],
        subjectId: 'business',
        teacherId: 'teacher-1',
        now: DateTime(2026, 9, 7),
        searchDays: 0,
      );

      expect(slots, hasLength(1));
      expect(slots.single.dateKey, '2026-09-07');
      expect(slots.single.sessionType, 'morning');
    },
  );

  test('reuse slots exclude another subject and missing teacher ownership', () {
    final slots = buildMissionReuseSlots(
      timetable: const [
        TodaySchedule(
          day: 'Monday',
          room: 'Room 1',
          morningMission: maths,
          afternoonMission: business,
          morningTeacher: teacher,
          afternoonTeacher: null,
        ),
      ],
      subjectId: 'business',
      teacherId: 'teacher-1',
      now: DateTime(2026, 9, 7),
      searchDays: 0,
    );

    expect(slots, isEmpty);
  });

  test('reuse API sends target slot and objective shuffle choices', () async {
    late http.Request capturedRequest;
    late Map<String, dynamic> capturedBody;
    final api = FocusMissionApi(
      client: MockClient((request) async {
        capturedRequest = request;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'mission': {
              'id': 'new-draft',
              'title': 'Business Q8 Revision',
              'status': 'draft',
              'sessionType': 'afternoon',
              'availableOnDate': '2026-09-08',
              'draftFormat': 'QUESTIONS',
              'questions': const [],
            },
          }),
          201,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final mission = await api.reuseTeacherMissionDraft(
      token: 'teacher-token',
      missionId: 'source-draft',
      targetStudentId: 'ahmed',
      targetDate: '2026-09-08',
      sessionType: 'afternoon',
      shuffleQuestionOrder: true,
      shuffleAnswerOptions: true,
    );

    expect(capturedRequest.method, 'POST');
    expect(
      capturedRequest.url.path,
      '/api/teacher/missions/source-draft/reuse',
    );
    expect(capturedRequest.headers['authorization'], 'Bearer teacher-token');
    expect(capturedBody, {
      'targetStudentId': 'ahmed',
      'targetDate': '2026-09-08',
      'sessionType': 'afternoon',
      'shuffleQuestionOrder': true,
      'shuffleAnswerOptions': true,
    });
    expect(mission.id, 'new-draft');
    expect(mission.status, 'draft');
    expect(mission.availableOnDate, '2026-09-08');
  });

  for (final size in const [Size(390, 844), Size(1280, 900)]) {
    testWidgets(
      'reuse sheet filters target students at ${size.width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final today = DateTime.now();
        const weekdayNames = <String>[
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
        final api = FocusMissionApi(
          client: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'timetable': [
                  {
                    'day': weekdayNames[today.weekday - 1],
                    'room': 'Room 1',
                    'morningMission': {'id': 'business', 'name': 'Business'},
                    'afternoonMission': {'id': 'maths', 'name': 'Maths'},
                    'morningTeacher': {
                      'id': 'teacher-1',
                      'name': 'Business Teacher',
                    },
                    'afternoonTeacher': {
                      'id': 'teacher-2',
                      'name': 'Other Teacher',
                    },
                  },
                ],
              }),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }),
        );
        const session = AuthSession(
          token: 'teacher-token',
          user: AppUser(
            id: 'teacher-1',
            name: 'Business Teacher',
            role: 'teacher',
          ),
        );
        const students = <StudentSummary>[
          StudentSummary(
            id: 'jace',
            name: 'Jace Mckenzie',
            xp: 0,
            streak: 0,
            yearGroup: 'Year 10',
          ),
          StudentSummary(
            id: 'sudais',
            name: 'Sudais Dahir',
            xp: 0,
            streak: 0,
            yearGroup: 'Year 9',
          ),
          StudentSummary(
            id: 'ahmed',
            name: 'Ahmed Stockwin',
            xp: 0,
            streak: 0,
            yearGroup: 'Year 10',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMissionReuseSheet(
                  context,
                  session: session,
                  sourceMission: sourceMission(),
                  sourceStudentId: 'jace',
                  students: students,
                  api: api,
                ),
                child: const Text('Open reuse'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open reuse'));
        await tester.pumpAndSettle();

        expect(find.text('Sudais Dahir · Year 9'), findsOneWidget);
        expect(find.text('Ahmed Stockwin · Year 10'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'initial sheet layout');
        await tester.tap(find.text('Year 10'));
        await tester.pumpAndSettle();
        expect(find.text('Sudais Dahir · Year 9'), findsNothing);
        expect(find.text('Ahmed Stockwin · Year 10'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'filtered sheet layout');

        await tester.tap(find.text('Ahmed Stockwin · Year 10'));
        await tester.pumpAndSettle();
        expect(find.text('Create draft for Ahmed Stockwin'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'scheduled sheet layout',
        );
      },
    );
  }
}
