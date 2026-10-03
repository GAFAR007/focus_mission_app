/**
 * WHAT: Tests the teacher's shared file/paste population and repair workflow.
 * WHY: Inputs and partial fields must survive validation/network failures;
 * duplicate taps cannot submit, and the original upload bytes must be preserved.
 * HOW: Open the real dialog at desktop/mobile sizes with controlled async previews.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/features/teacher/presentation/population_source_dialog.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';

UploadedSourceDraft result({
  bool ready = true,
}) => UploadedSourceDraft.fromJson({
  'draftReadiness': {
    'status': ready ? 'ready' : 'needs_attention',
    'summary': ready ? 'Content populated.' : 'Complete the missing content.',
    'missingRequirements': ready ? [] : ['Question 1 is missing Prompt.'],
  },
  'populationPreview': {
    'fields': [
      {'label': 'Assessment title', 'prefix': '', 'value': 'Local businesses'},
      {
        'label': 'Unit text',
        'prefix': 'UNIT TEXT:',
        'value': 'Businesses meet customer needs.',
      },
      {
        'label': 'Question 1 · Prompt',
        'prefix': 'Question 1:\nPrompt:',
        'value': ready ? 'What is a business?' : '',
      },
    ],
  },
});
Future<void> open(
  WidgetTester tester,
  PopulationPreview preview, {
  String format = 'QUESTIONS',
  double width = 1000,
  int? count,
  void Function(PlatformFile?)? onResult,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final source = await showPopulationSourceDialog(
                context: context,
                format: format,
                preview: preview,
                requiredQuestionCount: count,
              );
              onResult?.call(source);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  // Await even when onResult is absent (do not short-circuit the dialog call).
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> paste(WidgetTester tester, String text) async {
  await tester.tap(find.text('Paste Text'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('population-pasted-text')), text);
  await tester.ensureVisible(find.text('Populate from Text'));
  await tester.tap(find.text('Populate from Text'));
}

void main() {
  for (final format in ['QUESTIONS', 'THEORY', 'ESSAY_BUILDER']) {
    for (final width in [390.0, 1440.0]) {
      testWidgets(
        '$format paste populates visible fields and applies at $width',
        (tester) async {
          PlatformFile? selected;
          String received = '';
          await open(
            tester,
            (file) async {
              received = utf8.decode(file.bytes!);
              return result();
            },
            format: format,
            width: width,
            onResult: (file) => selected = file,
          );
          await paste(tester, 'Teacher structured content');
          await tester.pumpAndSettle();
          expect(received, 'Teacher structured content');
          expect(find.text('Content populated.'), findsOneWidget);
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('population-field-0')))
                .controller!
                .text,
            'Local businesses',
          );
          await tester.tap(find.byKey(const Key('population-apply')));
          await tester.pumpAndSettle();
          expect(utf8.decode(selected!.bytes!), 'Teacher structured content');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('empty and whitespace text never submit', (tester) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
      return result();
    }, onResult: (_) {});
    await paste(tester, '  \n\t ');
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(
      find.textContaining('Paste some assessment content before'),
      findsOneWidget,
    );
  });
  testWidgets(
    'pending population disables duplicate clicks, closing and apply',
    (tester) async {
      final pending = Completer<UploadedSourceDraft>();
      var calls = 0;
      await open(tester, (_) {
        calls++;
        return pending.future;
      }, onResult: (_) {});
      await paste(tester, 'Question 1 incomplete');
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Populating…'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Populating…'));
      await tester.pump();
      expect(calls, 1);
      pending.complete(result());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'partial content is editable and must be rechecked; errors retain fields',
    (tester) async {
      var calls = 0;
      String checked = '';
      await open(tester, (file) async {
        calls++;
        checked = utf8.decode(file.bytes!);
        if (calls == 2) throw Exception('Connection interrupted. Try again.');
        return result(ready: calls > 2);
      }, onResult: (_) {});
      await paste(tester, 'Partly valid content');
      await tester.pumpAndSettle();
      expect(find.text('• Question 1 is missing Prompt.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('population-apply')))
            .onPressed,
        isNull,
      );
      final field = find.byKey(const Key('population-field-2'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'What do businesses do?');
      await tester.ensureVisible(find.text('Check edited fields'));
      await tester.tap(find.text('Check edited fields'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not reach the content checker'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field).controller!.text,
        'What do businesses do?',
      );
      expect(checked, contains('Prompt: What do businesses do?'));
      await tester.ensureVisible(find.text('Check edited fields'));
      await tester.tap(find.text('Check edited fields'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('population-apply')))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'assessment requires ten questions without discarding partial fields',
    (tester) async {
      await open(tester, (_) async => result(), count: 10, onResult: (_) {});
      await paste(tester, 'Structured single question');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('exactly 10 questions; 1 were found'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('population-field-0')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('population-apply')))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('Upload File retains bytes/name and bypasses text preview', (
    tester,
  ) async {
    FilePicker.platform = _Picker();
    var previews = 0;
    PlatformFile? selected;
    await open(tester, (_) async {
      previews++;
      return result();
    }, onResult: (file) => selected = file);
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(previews, 0);
    expect(selected!.name, 'original.docx');
    expect(selected!.bytes, [1, 2, 3]);
  });
}

class _Picker extends FilePicker {
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
      name: 'original.docx',
      size: 3,
      bytes: Uint8List.fromList([1, 2, 3]),
    ),
  ]);
}
