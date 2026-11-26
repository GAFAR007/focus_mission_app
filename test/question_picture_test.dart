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
  testWidgets(
    'parent timer rebuilds keep the decoded picture and layout stable',
    (tester) async {
      final tick = ValueNotifier<int>(0);
      addTearDown(tick.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: tick,
              builder: (context, value, child) => Column(
                children: [
                  Text('Time $value'),
                  QuestionPicture(dataUrl: png, description: 'Code'),
                  const Text('Answer stays here'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final provider = tester.widget<Image>(find.byType(Image)).image;
      final answerPosition = tester.getTopLeft(find.text('Answer stays here'));
      for (var i = 1; i <= 3; i++) {
        tick.value = i;
        await tester.pump();
        expect(
          tester.widget<Image>(find.byType(Image)).image,
          provider,
          reason:
              'A countdown tick must reuse the decoded image, not restart image loading.',
        );
        expect(
          tester.getTopLeft(find.text('Answer stays here')),
          answerPosition,
        );
      }
    },
  );
  testWidgets('malformed picture leaves readable description', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QuestionPicture(dataUrl: 'invalid!', description: 'HTML source'),
      ),
    );
    expect(find.text('Picture unavailable. HTML source'), findsOneWidget);
  });
}
