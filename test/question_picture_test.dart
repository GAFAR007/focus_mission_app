/**
 * WHAT: Verifies accessible in-page question image enlargement.
 * WHY: Viewing code must not navigate away or lose the exam page.
 * HOW: Pump the shared picture, open/close zoom, and check malformed fallback.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/shared/widgets/question_picture.dart';

void main() {
  const png =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aQ1sAAAAASUVORK5CYII=';
  testWidgets('picture opens in-page zoom and returns to unchanged question', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                Text('Question remains'),
                QuestionPicture(dataUrl: png, description: 'HTML source'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enlarge picture'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.text('Close picture'));
    await tester.pumpAndSettle();
    expect(find.text('Question remains'), findsOneWidget);
    await tester.tap(find.text('Read picture description'));
    await tester.pumpAndSettle();
    expect(find.text('HTML source'), findsOneWidget);
  });
  testWidgets('malformed picture leaves readable description', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QuestionPicture(dataUrl: 'invalid!', description: 'HTML source'),
      ),
    );
    expect(find.text('Picture unavailable. HTML source'), findsOneWidget);
  });
}
