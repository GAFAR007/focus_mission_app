/**
 * WHAT:
 * Tests Task Focus pathway grouping and qualification-state separation.
 * WHY:
 * P1 work must stay ordered Q5 -> Q8 -> Essay -> Theory -> Assessment while a
 * tagged or completed mission must never manufacture criterion achievement.
 * HOW:
 * Build typed mission/certification fixtures and assert the pure grouping
 * output used by StudentCriterionMissionsScreen.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/teacher/presentation/student_criterion_missions_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  MissionPayload mission({
    required String id,
    required String format,
    required int questionCount,
    required List<String> taskCodes,
    String resultPackageId = '',
    Map<String, String> assessmentSequence = const {},
    int scoreCorrect = 0,
  }) {
    return MissionPayload.fromJson({
      'id': id,
      'title': id,
      'draftFormat': format,
      'questionCount': questionCount,
      'taskCodes': taskCodes,
      'status': 'published',
      'latestResultPackageId': resultPackageId,
      'scoreCorrect': scoreCorrect,
      'scoreTotal': questionCount,
      'scorePercent': questionCount == 0
          ? 0
          : ((scoreCorrect / questionCount) * 100).round(),
      'availableOnDate': '2026-09-10',
      'assessmentSequenceByTaskCode': assessmentSequence,
    });
  }

  SubjectCertificationSummary certification({
    required String taskCode,
    required String status,
    String bestMissionId = '',
    Map<String, dynamic> evidence = const {},
  }) {
    return SubjectCertificationSummary.fromJson({
      'subjectId': 'business-id',
      'subjectName': 'Business',
      'certificationEnabled': true,
      'requiredTaskCodes': [taskCode],
      'evidenceRows': [
        {
          'taskCode': taskCode,
          'status': status,
          'bestMissionId': bestMissionId,
          'reason': 'Backend-owned evidence',
          ...evidence,
        },
      ],
    });
  }

  test('orders the five P1 stages and treats the first assessment as A', () {
    final groups = buildMissionCriterionPathwayGroups(
      missions: [
        mission(
          id: 'assessment',
          format: 'QUESTIONS',
          questionCount: 10,
          taskCodes: ['P1'],
        ),
        mission(
          id: 'theory',
          format: 'THEORY',
          questionCount: 3,
          taskCodes: ['P1'],
        ),
        mission(
          id: 'essay',
          format: 'ESSAY_BUILDER',
          questionCount: 10,
          taskCodes: ['P1'],
        ),
        mission(
          id: 'q8',
          format: 'QUESTIONS',
          questionCount: 8,
          taskCodes: ['P1'],
        ),
        mission(
          id: 'q5',
          format: 'QUESTIONS',
          questionCount: 5,
          taskCodes: ['P1'],
        ),
      ],
      certifications: [certification(taskCode: 'P1', status: 'not_started')],
    );

    expect(groups, hasLength(1));
    expect(groups.single.entries.map((entry) => entry.stageLabel), [
      'Q5',
      'Q8',
      'Essay',
      'Theory',
      'Assessment A',
    ]);
  });

  test('preserves stored Assessment A and optional B sequence', () {
    final group = buildMissionCriterionPathwayGroups(
      missions: [
        mission(
          id: 'assessment-b',
          format: 'QUESTIONS',
          questionCount: 10,
          taskCodes: ['P1'],
          assessmentSequence: {'P1': 'B'},
        ),
        mission(
          id: 'assessment-a',
          format: 'QUESTIONS',
          questionCount: 10,
          taskCodes: ['P1'],
          assessmentSequence: {'P1': 'A'},
        ),
      ],
      certifications: const [],
    ).single;

    expect(group.assessmentEntries.map((entry) => entry.stageLabel), [
      'Assessment A',
      'Assessment B',
    ]);
  });

  test('keeps learning completion separate from criterion achievement', () {
    final group = buildMissionCriterionPathwayGroups(
      missions: [
        mission(
          id: 'q5-completed',
          format: 'QUESTIONS',
          questionCount: 5,
          taskCodes: ['P1'],
          resultPackageId: 'result-1',
        ),
      ],
      certifications: [certification(taskCode: 'P1', status: 'not_started')],
    ).single;

    expect(group.completedLearningCount, 1);
    expect(group.achievementLabel, 'Not yet achieved');
  });

  test('shows Essay as completed learning without achievement', () {
    final group = buildMissionCriterionPathwayGroups(
      missions: [
        mission(
          id: 'essay-completed',
          format: 'ESSAY_BUILDER',
          questionCount: 10,
          taskCodes: ['P1'],
          resultPackageId: 'essay-result',
        ),
      ],
      certifications: [certification(taskCode: 'P1', status: 'not_started')],
    ).single;

    expect(group.learningEntries.single.statusLabel, 'Completed');
    expect(group.achievementLabel, 'Not yet achieved');
  });

  test('shows separate Theory and Assessment A scores when achieved', () {
    final group = buildMissionCriterionPathwayGroups(
      missions: [
        mission(
          id: 'theory-passed',
          format: 'THEORY',
          questionCount: 3,
          taskCodes: ['P1'],
          resultPackageId: 'theory-result',
        ),
        mission(
          id: 'assessment-a-passed',
          format: 'QUESTIONS',
          questionCount: 10,
          taskCodes: ['P1'],
          resultPackageId: 'assessment-result',
          assessmentSequence: {'P1': 'A'},
          scoreCorrect: 8,
        ),
      ],
      certifications: [
        certification(
          taskCode: 'P1',
          status: 'passed',
          evidence: const {
            'theoryPassed': true,
            'theoryStatus': 'passed',
            'theoryScorePercent': 78,
            'theoryMissionId': 'theory-passed',
            'assessmentAPassed': true,
            'assessmentAStatus': 'passed',
            'assessmentACorrect': 8,
            'assessmentATotal': 10,
            'assessmentAMissionId': 'assessment-a-passed',
          },
        ),
      ],
    ).single;

    expect(group.learningEntries.single.statusLabel, 'Passed 78%');
    expect(group.assessmentEntries.single.statusLabel, 'Passed 8/10');
    expect(group.achievementLabel, 'Achieved');
  });

  test(
    'excludes untagged missions and keeps task codes in separate groups',
    () {
      final groups = buildMissionCriterionPathwayGroups(
        missions: [
          mission(
            id: 'legacy-null-focus',
            format: 'QUESTIONS',
            questionCount: 5,
            taskCodes: const [],
          ),
          mission(
            id: 'p2-q5',
            format: 'QUESTIONS',
            questionCount: 5,
            taskCodes: ['P2'],
          ),
        ],
        certifications: const [],
      );

      expect(groups.map((group) => group.taskCode), ['P2']);
      expect(groups.single.entries.single.mission.id, 'p2-q5');
      expect(groups.single.achievementLabel, 'Not configured');
    },
  );

  testWidgets('filters Ahmed pathway between P1 and P2 with optional B copy', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late Uri requestedUri;
    final api = FocusMissionApi(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'missions': [
              {
                'id': 'ahmed-p1-q5',
                'title': 'Ahmed P1 Q5',
                'draftFormat': 'QUESTIONS',
                'questionCount': 5,
                'taskCodes': ['P1'],
                'status': 'draft',
                'subject': {'id': 'business-id', 'name': 'Business'},
              },
              {
                'id': 'ahmed-p2-q8',
                'title': 'Ahmed P2 Q8',
                'draftFormat': 'QUESTIONS',
                'questionCount': 8,
                'taskCodes': ['P2'],
                'status': 'published',
                'subject': {'id': 'business-id', 'name': 'Business'},
              },
            ],
            'certifications': [
              {
                'subjectId': 'business-id',
                'subjectName': 'Business',
                'certificationEnabled': true,
                'requiredTaskCodes': ['P1', 'P2'],
                'evidenceRows': [
                  {'taskCode': 'P1', 'status': 'not_started'},
                  {'taskCode': 'P2', 'status': 'not_started'},
                ],
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentCriterionMissionsScreen(
          session: const AuthSession(
            token: 'teacher-token',
            user: AppUser(id: 'teacher-id', name: 'Teacher', role: 'teacher'),
          ),
          student: const StudentSummary(
            id: 'ahmed-id',
            name: 'Ahmed Stockwin',
            xp: 0,
            streak: 0,
          ),
          subjects: const [SubjectSummary(id: 'business-id', name: 'Business')],
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedUri.path, '/api/teacher/students/ahmed-id/mission-pathway');
    expect(requestedUri.queryParameters['subjectId'], 'business-id');
    expect(find.text('Ahmed P1 Q5'), findsOneWidget);
    expect(find.text('Ahmed P2 Q8'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mission_pathway_filter_P1')));
    await tester.pumpAndSettle();
    expect(find.text('Ahmed P1 Q5'), findsOneWidget);
    expect(find.text('Ahmed P2 Q8'), findsNothing);
    final optionalB = find.text('Assessment B · Optional · Not created');
    await tester.ensureVisible(optionalB);
    expect(optionalB, findsOneWidget);

    await tester.tap(find.byKey(const Key('mission_pathway_filter_P2')));
    await tester.pumpAndSettle();
    expect(find.text('Ahmed P1 Q5'), findsNothing);
    expect(find.text('Ahmed P2 Q8'), findsOneWidget);
  });
}
