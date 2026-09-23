/**
 * WHAT:
 * Verifies question upload defaults, safe-link rendering, and evidence panel
 * restore/visibility behavior.
 * WHY:
 * Student upload controls must stay opt-in while saved evidence and safe normal
 * web links remain available after a screen refresh.
 * HOW:
 * Decode real shared models and render widgets against a small mocked API.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:focus_mission_app/shared/widgets/question_evidence_panel.dart';
import 'package:focus_mission_app/shared/widgets/safe_link_text.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'MissionQuestion student upload permission defaults off and restores on',
    () {
      final historical = MissionQuestion.fromJson(const {
        'prompt': 'Historical question',
        'options': <String>[],
      });
      final enabled = MissionQuestion.fromJson(const {
        'prompt': 'Evidence question',
        'options': <String>[],
        'allowStudentUpload': true,
      });
      expect(historical.allowStudentUpload, isFalse);
      expect(enabled.allowStudentUpload, isTrue);
      expect(
        enabled.copyWith(allowStudentUpload: false).allowStudentUpload,
        isFalse,
      );
    },
  );

  testWidgets(
    'SafeLinkText links only normal web URLs and preserves exact text',
    (tester) async {
      const value =
          'Use https://school.example/work and www.example.com. '
          'Never javascript:alert(1) or data:text/html,test.';
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SafeLinkText(value))),
      );

      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      final spans = (selectable.textSpan as TextSpan).children!
          .cast<TextSpan>();
      expect(spans.map((span) => span.text).join(), value);
      expect(
        spans.where((span) => span.recognizer is TapGestureRecognizer).length,
        2,
      );
      expect(
        spans
            .where((span) => span.recognizer is TapGestureRecognizer)
            .map((span) => span.text),
        ['https://school.example/work', 'www.example.com'],
      );
    },
  );

  testWidgets('student evidence control is hidden when permission is off', (
    tester,
  ) async {
    await _pumpPanel(tester, allowUpload: false, files: const []);
    expect(find.text('Supporting evidence'), findsNothing);
    expect(find.text('Upload evidence'), findsNothing);
  });

  testWidgets('structured preview renders tables, formulas, and hyperlinks', (
    tester,
  ) async {
    final file = QuestionEvidenceFileData.fromJson(const {
      'id': 'sheet-1',
      'originalFileName': 'evidence.xlsx',
      'detectedType': 'xlsx',
      'parsedType': 'sheets',
      'previewStatus': 'available',
      'extractedContent': {
        'sheets': [
          {
            'name': 'Costs',
            'rows': [
              {
                'rowNumber': 1,
                'cells': ['Item', 'Cost'],
              },
              {
                'rowNumber': 2,
                'cells': [
                  {'text': 'Source', 'hyperlink': 'https://example.com/data'},
                  {'displayedValue': '12', 'formula': 'SUM(B2:B2)'},
                ],
              },
            ],
          },
        ],
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StructuredEvidencePreview(file: file)),
      ),
    );
    expect(find.text('Sheet: Costs'), findsOneWidget);
    expect(find.textContaining('https://example.com/data'), findsOneWidget);
    expect(find.textContaining('SUM(B2:B2)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('structured preview keeps Word blocks and slide ordering', (
    tester,
  ) async {
    final word = QuestionEvidenceFileData.fromJson(const {
      'id': 'word-1',
      'originalFileName': 'work.docx',
      'detectedType': 'docx',
      'parsedType': 'blocks',
      'previewStatus': 'available',
      'extractedContent': {
        'blocks': [
          {'type': 'heading', 'text': 'Evidence heading'},
          {
            'type': 'table',
            'rows': [
              ['Item', 'Result'],
              ['Project', 'Complete'],
            ],
          },
        ],
      },
    });
    final slides = QuestionEvidenceFileData.fromJson(const {
      'id': 'slides-1',
      'originalFileName': 'slides.pptx',
      'detectedType': 'pptx',
      'parsedType': 'slides',
      'previewStatus': 'available',
      'extractedContent': {
        'slides': [
          {
            'slideNumber': 1,
            'title': 'First slide',
            'blocks': [
              {'type': 'paragraph', 'text': 'First content'},
            ],
          },
          {
            'slideNumber': 2,
            'title': 'Second slide',
            'blocks': [
              {
                'type': 'list',
                'items': ['Second point'],
              },
            ],
          },
        ],
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              StructuredEvidencePreview(file: word),
              StructuredEvidencePreview(file: slides),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Evidence heading'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Slide 1: First slide'), findsOneWidget);
    expect(find.text('Slide 2: Second slide'), findsOneWidget);
    expect(find.text('• Second point'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft evidence exposes replace and remove before submission', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      allowUpload: true,
      files: const [
        {
          'id': 'draft-1',
          'originalFileName': 'draft.pdf',
          'detectedType': 'pdf',
          'fileSize': 1024,
          'parsedType': 'unavailable',
          'previewStatus': 'unavailable',
          'questionIndex': 0,
          'missionId': 'mission-1',
          'status': 'draft',
        },
      ],
    );
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('student evidence control appears when permission is enabled', (
    tester,
  ) async {
    await _pumpPanel(tester, allowUpload: true, files: const []);
    expect(find.text('Supporting evidence'), findsOneWidget);
    expect(find.text('Upload evidence'), findsOneWidget);
    expect(find.textContaining('maximum 10 MB'), findsOneWidget);
  });

  testWidgets('saved submitted evidence restores after the panel reloads', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      allowUpload: false,
      files: const [
        {
          'id': 'file-1',
          'originalFileName': 'project-evidence.docx',
          'mimeType':
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'detectedType': 'docx',
          'fileSize': 2048,
          'fileHash':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'parsedType': 'blocks',
          'previewStatus': 'available',
          'extractedContent': {
            'blocks': [
              {
                'type': 'paragraph',
                'text': 'Restored work https://example.com/source',
              },
            ],
          },
          'questionIndex': 0,
          'missionId': 'mission-1',
          'status': 'submitted',
        },
      ],
    );
    expect(find.text('project-evidence.docx'), findsOneWidget);
    expect(find.textContaining('DOCX'), findsOneWidget);
    expect(find.text('Upload evidence'), findsNothing);

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Restored work'), findsOneWidget);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required bool allowUpload,
  required List<Map<String, dynamic>> files,
}) async {
  final api = FocusMissionApi(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({'evidenceFiles': files}),
        200,
        headers: const {'content-type': 'application/json'},
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuestionEvidencePanel(
          api: api,
          token: 'student-token',
          missionId: 'mission-1',
          questionIndex: 0,
          asTeacher: false,
          allowUpload: allowUpload,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
