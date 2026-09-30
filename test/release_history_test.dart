/**
 * WHAT: Checks release history, account-specific awareness and narrow layouts.
 * WHY: Release information must remain accurate without disrupting app use.
 * HOW: Open the real widget with synthetic releases and local preference mocks.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_mission_app/shared/widgets/release_history_button.dart';

void main() {
  final history = <String, dynamic>{
    'version': '2.1.0',
    'releases': [
      {
        'version': '2.1.0',
        'releasedAt': '2026-09-30T00:00:00Z',
        'title': 'Clearer mission creation',
        'changes': {
          'new': ['See what changed in each release.'],
          'improved': <String>[],
          'fixed': ['Teachers can create missions reliably.'],
        },
      },
      {
        'version': '2.0.0',
        'releasedAt': null,
        'title': 'Previous production release',
        'changes': {
          'new': <String>[],
          'improved': ['Learning and progress tools.'],
          'fixed': <String>[],
        },
      },
    ],
  };

  testWidgets('viewing release notes clears New only for the current account', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    Widget app(String user) => MaterialApp(
      home: Scaffold(
        body: ReleaseHistoryButton(
          key: ValueKey(user),
          userId: user,
          history: history,
        ),
      ),
    );
    await tester.pumpWidget(app('teacher-one'));
    await tester.pumpAndSettle();
    expect(find.text('v2.1.0 • New'), findsOneWidget);
    await tester.tap(find.text('v2.1.0 • New'));
    await tester.pumpAndSettle();
    expect(find.text("What's New"), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('v2.0.0'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Fixed'), findsOneWidget);
    expect(find.text('Improved'), findsOneWidget); // Previous release only.
    await tester.tap(find.byTooltip('Close release history'));
    await tester.pumpAndSettle();
    expect(find.text('v2.1.0 • New'), findsNothing);
    await tester.pumpWidget(app('student-two'));
    await tester.pumpAndSettle();
    expect(find.text('v2.1.0 • New'), findsOneWidget);
    await tester.pumpWidget(app('teacher-one'));
    await tester.pumpAndSettle();
    expect(find.text('v2.1.0 • New'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('focusMission.releaseViewed.teacher-one'), '2.1.0');
    expect(prefs.getString('focusMission.releaseViewed.student-two'), isNull);
  });

  testWidgets('history fits a narrow screen with enlarged text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: ReleaseHistoryButton(userId: 'student', history: history),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('v2.1.0 • New'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Close release history'), findsOneWidget);
  });
}
