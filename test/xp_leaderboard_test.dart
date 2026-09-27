/**
 * WHAT: Validates the compact leaderboard interaction and narrow layout.
 * WHY: Ranking must remain optional and usable at phone sizes and large text.
 * HOW: Return synthetic server-ranked identities and exercise period/retry states.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/shared/models/xp_journey.dart';
import 'package:focus_mission_app/shared/widgets/xp_leaderboard_sheet.dart';

class _Api extends FocusMissionApi {
  String? period;
  bool fail = false;
  bool empty = false;
  @override
  Future<XpLeaderboard> fetchXpLeaderboard({
    required String token,
    String period = 'overall',
  }) async {
    this.period = period;
    if (fail) throw Exception('synthetic failure');
    return XpLeaderboard.fromJson({
      'myRank': empty ? null : 2,
      'partialWeek': true,
      'trackingStartedAt': '2026-09-27T10:00:00Z',
      'entries': empty
          ? []
          : [
              {
                'rank': 1,
                'name': 'Alexandra M.',
                'totalXp': 12000,
                'weeklyXp': 70,
                'milestone': 10000,
                'isYou': false,
              },
              {
                'rank': 2,
                'name': 'Sam D.',
                'totalXp': 554,
                'weeklyXp': 20,
                'milestone': 500,
                'isYou': true,
              },
            ],
    });
  }
}

void main() {
  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('leaderboard wraps at $width with accessible text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: XpLeaderboardSheet(api: api, token: 'synthetic'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My rank #2'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('YOU · Sam D.'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('YOU · Sam D.'), findsOneWidget);
      expect(api.period, 'overall');
      await tester.tap(find.text('This week'));
      await tester.pumpAndSettle();
      expect(api.period, 'weekly');
      expect(find.textContaining('Partial week'), findsOneWidget);
      expect(find.text('20 XP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('leaderboard retries errors and renders an empty school', (
    tester,
  ) async {
    final api = _Api()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XpLeaderboardSheet(api: api, token: 'synthetic'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The leaderboard could not load.'), findsOneWidget);
    api.fail = false;
    api.empty = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No active students yet.'), findsOneWidget);
  });
}
