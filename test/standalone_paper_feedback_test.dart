/**
 * WHAT: Checks visible objective correctness in both Test and Exam players.
 * WHY: Colour needs a readable legend and theory must wait for teacher marking.
 * HOW: Save synthetic selections through a fake API and inspect labels and colours.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/student/presentation/standalone_paper_play_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';

class _FeedbackApi extends FocusMissionApi {
  _FeedbackApi(this.kind, this.theory);
  final String kind;
  final bool theory;
  int selected = -1;
  StartedStandalonePaperSession state() =>
      StartedStandalonePaperSession.fromJson({
        'paper': {
          'id': 'paper',
          'paperKind': kind,
          'title': 'Feedback fixture',
          'items': [
            {
              'itemIndex': 0,
              'itemType': theory ? 'THEORY' : 'OBJECTIVE',
              'prompt': 'Choose a value',
              'options': ['Alpha', 'Beta', 'Gamma', 'Delta'],
            },
          ],
        },
        'session': {
          'id': 'sitting',
          'status': 'active',
          'totalItems': 1,
          'responses': [
            {
              'itemIndex': 0,
              'itemType': theory ? 'THEORY' : 'OBJECTIVE',
              'selectedOptionIndex': selected,
              'isCorrect': theory || selected < 0 ? null : selected == 2,
            },
          ],
        },
      });
  @override
  Future<StartedStandalonePaperSession> startStandalonePaperSession({
    required String token,
    required String studentId,
    required String paperId,
  }) async => state();
  @override
  Future<StartedStandalonePaperSession> saveStandalonePaperSessionProgress({
    required String token,
    required String studentId,
    required String sessionId,
    required int itemIndex,
    int? selectedOptionIndex,
    String? textAnswer,
    bool? flagged,
    int? currentItemIndex,
  }) async {
    selected = selectedOptionIndex ?? selected;
    return state();
  }
}

void main() {
  for (final kind in ['TEST', 'EXAM']) {
    testWidgets('$kind shows correct and incorrect saved selections', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _FeedbackApi(kind, false);
      await tester.pumpWidget(
        MaterialApp(
          home: StandalonePaperPlayScreen(
            session: const AuthSession(
              token: 'fixture',
              user: AppUser(id: 'learner', name: 'Learner', role: 'student'),
            ),
            paperId: 'paper',
            api: api,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Green = correct'), findsOneWidget);
      expect(find.text('Red = incorrect'), findsOneWidget);
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect answer'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Incorrect answer')).style!.color,
        const Color(0xFFB3261E),
      );
      await tester.tap(find.text('Gamma'));
      await tester.pumpAndSettle();
      expect(find.text('Correct answer'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Correct answer')).style!.color,
        const Color(0xFF176B3A),
      );
      expect(api.selected, 2);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('$kind leaves theory marking to the teacher', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StandalonePaperPlayScreen(
            session: const AuthSession(
              token: 'fixture',
              user: AppUser(id: 'learner', name: 'Learner', role: 'student'),
            ),
            paperId: 'paper',
            api: _FeedbackApi(kind, true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your teacher will mark this answer.'), findsOneWidget);
      expect(find.text('Green = correct'), findsNothing);
      expect(find.text('Correct answer'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
