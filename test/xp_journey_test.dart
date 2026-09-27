/**
 * WHAT: Checks the long-term journey thresholds and responsive presentation.
 * WHY: Existing XP must remain intact and keep growing beyond 6K and 10K.
 * HOW: Verify boundary values and render the shared hero/profile panel.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/shared/models/xp_journey.dart';
import 'package:focus_mission_app/shared/widgets/xp_journey_panel.dart';

void main() {
  test('persisted milestones survive a later score correction', () {
    const journey = XpJourney(
      5900,
      achievements: [XpAchievement(threshold: 6000)],
    );
    expect(journey.journeyComplete, isTrue);
    expect(journey.highestMilestone, 6000);
    expect(journey.nextMilestone, 10000);
    expect(journey.remainingXp, 4100);
  });

  test('existing 554 XP remains unchanged and points to 1K', () {
    const journey = XpJourney(554);
    expect(journey.totalXp, 554);
    expect(journey.highestMilestone, 500);
    expect(journey.nextMilestone, 1000);
    expect(journey.remainingXp, 446);
    expect(journey.progress, closeTo(554 / 6000, 0.0001));
  });
  for (final threshold in XpJourney.milestones) {
    test('$threshold boundary advances only when reached', () {
      final before = XpJourney(threshold - 1);
      final reached = XpJourney(threshold);
      expect(before.nextMilestone, threshold);
      expect(before.remainingXp, 1);
      expect(reached.highestMilestone, threshold);
      expect(reached.totalXp, threshold);
      expect(reached.nextMilestone, isNot(threshold));
    });
  }
  test('6K completes the journey without capping XP', () {
    const journey = XpJourney(6420);
    expect(journey.journeyComplete, isTrue);
    expect(journey.totalXp, 6420);
    expect(journey.nextMilestone, 10000);
    expect(journey.remainingXp, 3580);
    expect(journey.progress, 1);
    expect(const XpJourney(12000).totalXp, 12000);
    expect(const XpJourney(12000).nextMilestone, isNull);
  });
  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('journey and stretch display wrap at $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: XpJourneyPanel(totalXp: 554),
            ),
          ),
        ),
      );
      expect(find.text('554 / 6,000 XP'), findsOneWidget);
      expect(
        find.text('Next milestone: 1,000 XP · 446 XP to go'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: XpJourneyPanel(totalXp: 6420, onDark: true),
            ),
          ),
        ),
      );
      expect(find.text('6K Journey Complete'), findsOneWidget);
      expect(find.text('Total XP: 6,420'), findsOneWidget);
      expect(
        find.text('Next milestone: 10,000 XP · 3,580 XP to go'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
