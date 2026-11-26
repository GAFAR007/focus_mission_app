/**
 * WHAT: Verifies mission picture editing and transport.
 * WHY: A teacher's image and description must survive replacement and saving.
 * HOW: Pick synthetic raster files and inspect the real API's JSON request.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/shared/widgets/question_picture_editor.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aQ1sAAAAASUVORK5CYII=';
void main() {
  testWidgets(
    'optional picker adds, replaces and removes pictures without losing description',
    (tester) async {
      FilePicker.platform = _PicturePicker();
      var data = '', description = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuestionPictureEditor(
                dataUrl: '',
                description: '',
                onChanged: (url, text) {
                  data = url;
                  description = text;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add picture (optional)'));
      await tester.pumpAndSettle();
      expect(data, 'data:image/png;base64,$png');
      await tester.enterText(
        find.byType(TextFormField),
        'The loop prints each number.',
      );
      await tester.tap(find.text('Replace picture'));
      await tester.pumpAndSettle();
      expect(description, 'The loop prints each number.');
      expect(find.text('Enlarge picture'), findsOneWidget);
      await tester.tap(find.text('Remove picture'));
      await tester.pumpAndSettle();
      expect(data, '');
      expect(description, '');
      expect(find.text('Add picture (optional)'), findsOneWidget);
    },
  );
  test(
    'question images round-trip through copy, save request and server response',
    () async {
      final question = MissionQuestion.fromJson({
        'id': 'q1',
        'imageDataUrl': 'data:image/png;base64,$png',
        'imageDescription': 'A code example',
      }).copyWith(prompt: 'Read the code');
      final api = FocusMissionApi(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['questions'][0]['imageDataUrl'], question.imageDataUrl);
          expect(
            body['questions'][0]['imageDescription'],
            question.imageDescription,
          );
          return http.Response(jsonEncode({'mission': body}), 200);
        }),
      );
      final saved = await api.updateTeacherMission(
        token: 'test',
        missionId: 'm1',
        title: 'Q5',
        teacherNote: '',
        sourceUnitText: '',
        difficulty: 'medium',
        xpReward: 10,
        questions: [question],
      );
      expect(saved.questions.single.imageDataUrl, question.imageDataUrl);
      expect(
        saved.questions.single.imageDescription,
        question.imageDescription,
      );
    },
  );
}

class _PicturePicker extends FilePicker {
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
      name: 'code.png',
      size: base64Decode(png).length,
      bytes: base64Decode(png),
    ),
  ]);
}
