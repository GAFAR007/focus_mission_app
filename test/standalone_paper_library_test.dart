/**
 * WHAT: Exercises teacher Test and Exam browsing, preview, and publishing.
 * WHY: A teacher must open the right learner's saved questions and retain the
 * existing publishing checks while combining subject, type, and status filters.
 * HOW: Pump the real library and editor using a synthetic, recording API.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/theme/app_theme.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/teacher/models/standalone_paper_models.dart';
import 'package:focus_mission_app/features/teacher/presentation/standalone_paper_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';

const _session = AuthSession(
  token: 'synthetic-token',
  user: AppUser(id: 'teacher', name: 'Teacher', role: 'teacher'),
);
const _student = StudentSummary(
  id: 'learner',
  name: 'Learner Alpha',
  xp: 0,
  streak: 0,
);

StandalonePaperDraft _paper(
  String id,
  String title,
  String kind,
  String status, {
  String subject = 'Business',
}) => StandalonePaperDraft.fromJson({
  'id': id,
  'teacherId': 'teacher',
  'studentId': 'learner',
  'title': title,
  'paperKind': kind,
  'status': status,
  'targetDate': '2026-11-19',
  'sessionType': 'morning',
  'durationMinutes': kind == 'EXAM' ? 30 : 0,
  'subject': {'id': subject.toLowerCase(), 'name': subject},
  'sourceUnitText': 'Read this learning passage.',
  'itemCount': 3,
  'items': [
    {
      'itemType': 'OBJECTIVE',
      'learningText': 'Learn about working links.',
      'prompt': 'Which link works?',
      'options': ['Alpha', 'Beta', 'Gamma', 'Delta'],
      'correctIndex': 1,
      'explanation': 'Beta matches the file.',
    },
    {
      'itemType': 'FILL_GAP',
      'prompt': 'The Home page is _____.',
      'expectedAnswer': 'index.html',
      'acceptedAnswers': ['index.html'],
    },
    {
      'itemType': 'THEORY',
      'prompt': 'Explain how to test the link.',
      'expectedAnswer': 'Save and click the link.',
      'minWordCount': 30,
      'explanation': 'Credit a browser check.',
    },
  ],
});

class _PaperApi extends FocusMissionApi {
  List<StandalonePaperDraft> papers = [
    _paper('test-draft', 'Business draft', 'TEST', 'draft'),
    _paper('test-live', 'Business published', 'TEST', 'published'),
    _paper('exam-draft', 'Sport draft', 'EXAM', 'draft', subject: 'Sport'),
    _paper(
      'exam-live',
      'Sport published',
      'EXAM',
      'published',
      subject: 'Sport',
    ),
  ];
  final requests = <String>[];
  final publishedIds = <String>[];
  bool failLoad = false;
  bool rejectPublish = false;

  @override
  Future<List<StandalonePaperDraft>> fetchStandalonePapers({
    required String token,
    required String studentId,
    required String paperKind,
  }) async {
    requests.add('$studentId:$paperKind');
    if (failLoad) throw Exception('Could not load saved papers');
    return papers.where((p) => p.paperKind == paperKind).toList();
  }

  @override
  Future<StandalonePaperSessionState?> fetchLatestStandalonePaperSession({
    required String token,
    required String paperId,
  }) async => null;

  @override
  Future<StandalonePaperDraft> publishStandalonePaper({
    required String token,
    required String paperId,
  }) async {
    if (rejectPublish) throw Exception('Publishing was rejected by the server');
    publishedIds.add(paperId);
    final saved = papers
        .firstWhere((p) => p.id == paperId)
        .copyWith(status: 'published');
    papers = [for (final p in papers) p.id == paperId ? saved : p];
    return saved;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _PaperApi api, {
  Size size = const Size(1440, 1800),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: StandalonePaperLibraryScreen(
        session: _session,
        student: _student,
        api: api,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'loads this learner and composes subject, status and paper filters',
    (tester) async {
      final api = _PaperApi();
      await _pump(tester, api);
      expect(api.requests, containsAll(['learner:TEST', 'learner:EXAM']));
      expect(find.text('4 papers'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Drafts'));
      await tester.pumpAndSettle();
      expect(find.text('2 papers'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sport').last);
      await tester.pumpAndSettle();
      expect(find.text('Sport draft'), findsOneWidget);
      expect(find.text('Business draft'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tests'));
      await tester.pumpAndSettle();
      expect(find.text('0 papers'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Exams'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Published'));
      await tester.pumpAndSettle();
      expect(find.text('Sport published'), findsOneWidget);
      expect(find.text('Sport draft'), findsNothing);
    },
  );

  testWidgets('published questions and answer keys have a read-only preview', (
    tester,
  ) async {
    final api = _PaperApi();
    await _pump(tester, api);
    await tester.tap(find.byKey(const ValueKey('preview-paper-test-live')));
    await tester.pumpAndSettle();
    expect(
      find.text('Published · 3 questions · Read-only preview'),
      findsOneWidget,
    );
    expect(find.text('Which link works?'), findsOneWidget);
    expect(find.text('The Home page is _____.'), findsOneWidget);
    expect(find.text('Explain how to test the link.'), findsOneWidget);
    expect(find.text('Minimum 30 words'), findsOneWidget);
    await tester.tap(find.text('Answer & marking notes').first);
    await tester.pumpAndSettle();
    expect(find.text('Correct answer: B) Beta'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(api.publishedIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'review opens the chosen draft and publishing refreshes the library',
    (tester) async {
      final api = _PaperApi();
      await _pump(tester, api);
      await tester.tap(find.byKey(const ValueKey('manage-paper-exam-draft')));
      await tester.pumpAndSettle();
      expect(find.text('Standalone Exam'), findsOneWidget);
      final title = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Exam title'),
      );
      expect(title.controller!.text, 'Sport draft');
      final publish = find.text('Publish Exam');
      await tester.ensureVisible(publish);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(api.publishedIds, ['exam-draft']);
      expect(find.text('Unpublish Exam'), findsOneWidget);
      final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
      await tester.ensureVisible(back);
      await tester.tap(back);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Drafts'));
      await tester.pumpAndSettle();
      expect(find.text('Sport draft'), findsNothing);
      expect(find.text('1 paper'), findsOneWidget);
    },
  );

  testWidgets('server rejection does not mark a draft published', (
    tester,
  ) async {
    final api = _PaperApi()..rejectPublish = true;
    await _pump(tester, api);
    await tester.tap(find.byKey(const ValueKey('manage-paper-test-draft')));
    await tester.pumpAndSettle();
    final publish = find.text('Publish Test');
    await tester.ensureVisible(publish);
    await tester.tap(publish);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Publishing was rejected by the server'),
      findsOneWidget,
    );
    expect(api.publishedIds, isEmpty);
    expect(find.text('Publish Test'), findsOneWidget);
  });

  testWidgets('load errors offer retry and filters wrap on phones', (
    tester,
  ) async {
    final api = _PaperApi()..failLoad = true;
    await _pump(tester, api, size: const Size(390, 844));
    expect(find.text('Retry'), findsOneWidget);
    api.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Exams'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Published'));
    await tester.pumpAndSettle();
    expect(find.text('1 paper'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
