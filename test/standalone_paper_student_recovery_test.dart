/**
 * WHAT: Checks the learner can return after a teacher reinstates a sitting.
 * WHY: A locked screen must offer a usable return path without losing answers.
 * HOW: Pump the real player with a locked attempt followed by saved active work.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/theme/app_theme.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/features/student/presentation/standalone_paper_play_screen.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';

class _RecoveryApi extends FocusMissionApi {
  int starts = 0;
  @override
  Future<StartedStandalonePaperSession> startStandalonePaperSession({
    required String token,
    required String studentId,
    required String paperId,
  }) async {
    starts++;
    return StartedStandalonePaperSession.fromJson({
      'paper': {
        'id': paperId,
        'paperKind': 'TEST',
        'title': 'Business test',
        'items': [
          {
            'itemIndex': 0,
            'itemType': 'OBJECTIVE',
            'prompt': 'Which answer was saved?',
            'options': ['Saved answer', 'B', 'C', 'D'],
          },
        ],
      },
      'session': {
        'id': 'sitting',
        'paperId': paperId,
        'status': starts == 1 ? 'locked' : 'active',
        'totalItems': 1,
        'answeredCount': 1,
        'responses': [
          {'itemIndex': 0, 'itemType': 'OBJECTIVE', 'selectedOptionIndex': 0},
        ],
      },
    });
  }
}

void main() {
  testWidgets('locked learner can resume the saved sitting', (tester) async {
    final api = _RecoveryApi();
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
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
    expect(find.text('Test locked'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(api.starts, 2);
    expect(find.text('Which answer was saved?'), findsOneWidget);
    expect(find.text('Saved answer'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
