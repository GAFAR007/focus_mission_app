/**
 * WHAT:
 * Verifies daily format presets, generation contracts, responsive setup and review.
 * WHY:
 * The teacher editor must use the available viewport without mobile overflow
 * and must never silently discard changed draft content.
 * HOW:
 * Open the real builder with mocked APIs at phone, tablet and desktop sizes;
 * check types, task codes, XP, assessment routing and the protected Back flow.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/teacher/presentation/mission_builder_sheet.dart';
import 'package:focus_mission_app/features/teacher/presentation/assessment_mode_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dedicated assessment entry still opens assessment workflow', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 1100));
    await _openReviewDraft(tester, newDraft: true, openAssessmentOnStart: true);
    expect(find.byType(AssessmentModeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI upload cannot change a daily Objective into an assessment', (
    tester,
  ) async {
    FilePicker.platform = _SourceFilePicker();
    await _setViewport(tester, const Size(1440, 1100));
    await _openReviewDraft(
      tester,
      newDraft: true,
      apiOverride: _AssessmentSuggestionApi(),
    );
    await tester.tap(find.text('8 questions · Revision'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('AI draft'));
    await tester.tap(find.text('AI draft'));
    await tester.pumpAndSettle();
    expect(find.text('10 questions · Assessment'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('mission-title')))
          .controller!
          .text,
      'Objective Q8',
    );
    expect(find.text('30 XP'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('mission-format-theory')));
    await tester.tap(find.byKey(const Key('mission-format-theory')));
    await tester.pumpAndSettle();
    expect(find.text('Build Theory Mission'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final format in DailyMissionFormat.values) {
    for (final width in [390.0, 768.0, 1440.0]) {
      testWidgets(
        '${format.name} creation is focused and responsive at $width',
        (tester) async {
          await _setViewport(tester, Size(width, 1000));
          await _openReviewDraft(tester, newDraft: true, initialFormat: format);
          final label = switch (format) {
            DailyMissionFormat.objective => 'Objective',
            DailyMissionFormat.theory => 'Theory',
            DailyMissionFormat.essay => 'Essay',
          };
          expect(find.text('Build $label Mission'), findsOneWidget);
          expect(find.text('Generate $label Draft'), findsOneWidget);
          expect(find.text('Easy'), findsNothing);
          expect(find.text('Medium'), findsNothing);
          expect(find.text('Hard'), findsNothing);
          expect(find.text('10 questions · Assessment mode'), findsNothing);
          expect(
            find.text('5 questions · Daily'),
            format == DailyMissionFormat.objective
                ? findsOneWidget
                : findsNothing,
          );
          expect(
            find.byType(Slider),
            format == DailyMissionFormat.theory ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('STRETCH_15'),
            format == DailyMissionFormat.essay ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('Populate objective'),
            format == DailyMissionFormat.objective
                ? findsOneWidget
                : findsNothing,
          );
          expect(
            find.text('Populate theory'),
            format == DailyMissionFormat.theory ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('Populate essay'),
            format == DailyMissionFormat.essay ? findsOneWidget : findsNothing,
          );
          await tester.ensureVisible(
            find.byKey(const Key('generate-daily-mission')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('all task focuses keep canonical titles and multiple selection', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 1100));
    await _openReviewDraft(
      tester,
      newDraft: true,
      initialFormat: DailyMissionFormat.theory,
    );
    final title = find.byKey(const Key('mission-title'));
    for (final code in [
      'P1',
      'P2',
      'P3',
      'P4',
      'P5',
      'P6',
      'P7',
      'M1',
      'M2',
      'M3',
      'D1',
      'D2',
    ]) {
      final choice = find.byKey(ValueKey('mission-task-$code'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(title).controller!.text,
        '$code Theory Q5',
      );
      await tester.tap(choice);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byKey(const Key('mission-task-P1')));
    await tester.tap(find.byKey(const Key('mission-task-P1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mission-task-P2')));
    await tester.tap(find.byKey(const Key('mission-task-P2')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(title).controller!.text,
      'P1 + P2 Theory Q5',
    );
  });

  for (final example in [
    (DailyMissionFormat.objective, 5, 30),
    (DailyMissionFormat.objective, 8, 30),
    (DailyMissionFormat.theory, 5, 50),
    (DailyMissionFormat.essay, 5, 20),
  ]) {
    testWidgets(
      '${example.$1.name} Q${example.$2} keeps generation context and XP',
      (tester) async {
        Map<String, dynamic>? submitted;
        final api = FocusMissionApi(
          client: MockClient((request) async {
            if (!request.url.path.endsWith('/missions/generate')) {
              return http.Response(jsonEncode({'certifications': []}), 200);
            }
            submitted = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'mission': {
                  ...submitted!,
                  'id': 'generated',
                  'status': 'draft',
                  'draftJson': example.$1 == DailyMissionFormat.essay
                      ? <String, dynamic>{}
                      : null,
                  'questions': example.$1 == DailyMissionFormat.essay
                      ? []
                      : List.generate(
                          example.$2,
                          (i) => {
                            'id': 'q$i',
                            'prompt': 'Explain the business',
                            'learningText':
                                'Businesses provide goods and services.',
                            'options': ['A', 'B', 'C', 'D'],
                            'correctIndex': 0,
                            'answerMode':
                                example.$1 == DailyMissionFormat.theory
                                ? 'short_answer'
                                : 'multiple_choice',
                            'expectedAnswer':
                                'Businesses provide goods and services.',
                            'minWordCount': 10,
                          },
                        ),
                },
              }),
              200,
            );
          }),
        );
        await _setViewport(tester, const Size(1440, 1100));
        await _openReviewDraft(
          tester,
          newDraft: true,
          initialFormat: example.$1,
          apiOverride: api,
        );
        await tester.tap(find.byKey(const Key('mission-task-P2')));
        await tester.pumpAndSettle();
        if (example.$2 == 8) {
          await tester.tap(find.text('8 questions · Revision'));
          await tester.pumpAndSettle();
        }
        final source = find.byKey(const Key('mission-source-text'));
        await tester.ensureVisible(source);
        await tester.enterText(
          source,
          'Businesses provide goods and services to customers. This lesson explains how different businesses operate and meet customer needs.',
        );
        await tester.ensureVisible(
          find.byKey(const Key('generate-daily-mission')),
        );
        await tester.tap(find.byKey(const Key('generate-daily-mission')));
        await tester.pumpAndSettle();
        expect(submitted?['draftFormat'], example.$1.draftFormat);
        expect(submitted?['questionCount'], example.$2);
        expect(submitted?['xpReward'], example.$3);
        expect(submitted?['difficulty'], 'medium');
        expect(submitted?['taskCodes'], ['P2']);
        expect(submitted?['studentId'], 'student-1');
        expect(submitted?['subjectId'], 'subject-1');
        expect(submitted?['sessionType'], 'morning');
        expect(find.text('Review Draft'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'certification retains required, single-task and format conditions',
    (tester) async {
      final api = FocusMissionApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'certifications': [
                {
                  'subjectId': 'subject-1',
                  'certificationLabel': 'Course Certification',
                  'requiredTaskCodes': ['P1', 'P2'],
                  'remainingTaskCodes': ['P1', 'P2'],
                  'passedTaskCodes': [],
                },
              ],
            }),
            200,
          ),
        ),
      );
      await _setViewport(tester, const Size(1440, 1100));
      await _openReviewDraft(tester, newDraft: true, apiOverride: api);
      expect(find.text('Course Certification'), findsOneWidget);
      expect(
        find.textContaining(
          'only essays, theory, and 10+ question missions qualify',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('mission-format-theory')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'To count toward certification, choose exactly one task focus.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('mission-task-P1')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'This mission can count toward certification if the student passes it.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('mission-task-P2')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('more than one task focus is selected'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy editor title is canonical on open', (tester) async {
    await _setViewport(tester, const Size(1440, 1000));
    await _openReviewDraft(
      tester,
      draft: _draft().copyWith(title: 'Business Morning Mission'),
    );
    expect(find.text('P1 Objective Q5'), findsOneWidget);
  });

  testWidgets('new editor title follows type and preserves custom wording', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 1000));
    await _openReviewDraft(tester, newDraft: true);
    final titleField = find.byType(TextFormField).first;
    expect(
      tester.widget<TextFormField>(titleField).controller!.text,
      'Objective Q5',
    );
    await tester.tap(find.text('Theory').first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(titleField).controller!.text,
      'Theory Q5',
    );
    await tester.enterText(titleField, 'How local businesses grow');
    await tester.tap(find.byKey(const Key('mission-format-essay')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(titleField).controller!.text,
      'How local businesses grow',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Review Draft uses a wide desktop workspace and protects edits', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 1000));
    await _openReviewDraft(tester);

    final workspace = find.byType(FractionallySizedBox).last;
    expect(tester.getSize(workspace).width, greaterThan(1250));
    expect(find.text('Review Draft'), findsOneWidget);
    expect(find.text('Draft only'), findsOneWidget);
    expect(find.text('Task Focus: P1'), findsOneWidget);
    expect(find.text('Student file upload'), findsOneWidget);
    final uploadToggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('allow_student_upload_toggle')),
    );
    expect(uploadToggle.value, isFalse);
    expect(find.text('Teacher evidence for question 1'), findsOneWidget);
    expect(find.text('Upload evidence'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Changed title');
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Leave Review Draft?'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.text('Discard edits'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Review Draft'), findsOneWidget);
  });

  testWidgets('Review Draft fills a narrow phone without horizontal overflow', (
    tester,
  ) async {
    final overflowErrors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        overflowErrors.add(details);
        return;
      }
      previousErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousErrorHandler);

    await _setViewport(tester, const Size(390, 844));
    await _openReviewDraft(tester);

    final workspace = find.byType(FractionallySizedBox).last;
    expect(tester.getSize(workspace).width, 390);
    expect(find.text('Review Draft'), findsOneWidget);
    expect(overflowErrors, isEmpty);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _openReviewDraft(
  WidgetTester tester, {
  MissionPayload? draft,
  bool newDraft = false,
  bool openAssessmentOnStart = false,
  DailyMissionFormat initialFormat = DailyMissionFormat.objective,
  FocusMissionApi? apiOverride,
}) async {
  final api =
      apiOverride ??
      FocusMissionApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'certifications': <dynamic>[]}),
            200,
            headers: const {'content-type': 'application/json'},
          ),
        ),
      );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              showMissionBuilderSheet(
                context,
                session: const AuthSession(
                  token: 'teacher-token',
                  user: AppUser(
                    id: 'teacher-1',
                    name: 'Teacher One',
                    role: 'teacher',
                  ),
                ),
                student: const StudentSummary(
                  id: 'student-1',
                  name: 'Student One',
                  xp: 0,
                  streak: 0,
                ),
                subject: const SubjectSummary(
                  id: 'subject-1',
                  name: 'Business',
                ),
                sessionType: 'morning',
                targetDate: DateTime.now(),
                api: api,
                initialFormat: initialFormat,
                openAssessmentOnStart: openAssessmentOnStart,
                initialDraft: newDraft ? null : draft ?? _draft(),
              );
            },
            child: const Text('Open review'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open review'));
  await tester.pumpAndSettle();
}

MissionPayload _draft() {
  return MissionPayload(
    id: 'mission-1',
    title: 'Business Online',
    teacherNote: 'Read carefully.',
    sourceUnitText: 'Business Online unit text.',
    sourceRawText: '',
    sourceFileName: '',
    sourceFileType: '',
    draftFormat: 'QUESTIONS',
    essayMode: '',
    draftJson: null,
    source: 'teacher_ai',
    status: 'draft',
    sessionType: 'morning',
    difficulty: 'medium',
    taskCodes: const ['P1'],
    xpReward: 30,
    xpEarned: 0,
    questionCount: 5,
    scoreCorrect: 0,
    scoreTotal: 5,
    scorePercent: 0,
    latestResultPackageId: '',
    questions: const [
      MissionQuestion(
        id: 'question-1',
        answerMode: 'multiple_choice',
        learningText: 'An online business trades using the internet.',
        prompt: 'What is an online business?',
        options: ['Online trade', 'A room', 'A timetable', 'A letter'],
        correctIndex: 0,
        explanation: 'Online trade is the correct definition.',
        expectedAnswer: '',
        minWordCount: 0,
      ),
    ],
  );
}

// Synthetic upload keeps the source workflow entirely offline in widget tests.
class _SourceFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(
      name: 'lesson.txt',
      size: 6,
      bytes: Uint8List.fromList(utf8.encode('lesson')),
    ),
  ]);
}

class _AssessmentSuggestionApi extends FocusMissionApi {
  _AssessmentSuggestionApi()
    : super(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'certifications': []}), 200),
        ),
      );

  @override
  Future<UploadedSourceDraft> uploadTeacherSourceDraft({
    required String token,
    required String subjectId,
    required String sessionType,
    required List<int> fileBytes,
    required String fileName,
    String uploadMode = 'ai_draft',
    bool previewOnly = false,
    String studentId = '',
    String targetDate = '',
    String title = '',
    String draftFormat = 'QUESTIONS',
    String essayMode = '',
    String difficulty = 'medium',
    int? questionCount,
    List<String> taskCodes = const [],
    String missionDraftId = '',
  }) async => UploadedSourceDraft.fromJson({
    'fileName': fileName,
    'mimeType': 'text/plain',
    'extractedText':
        'Businesses provide goods and services to customers. This lesson explains how different businesses operate and meet customer needs.',
    'unitPlan': {'suggestedQuestionCount': 10},
    'draftReadiness': {'status': 'ready'},
  });
}
