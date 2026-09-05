/**
 * WHAT:
 * Verifies that the app reaches the Focus Mission role-selection screen.
 * WHY:
 * App startup restores a saved session asynchronously, so the smoke test must
 * cover the completed boot lifecycle rather than assert during its loader.
 * HOW:
 * Start with empty test preferences, pump the real app, await settled startup,
 * and assert the unauthenticated role choices.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders the Focus Mission role selection screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const FocusMissionApp());
    await tester.pumpAndSettle();

    expect(find.text('Focus Mission'), findsOneWidget);
    expect(find.text('Choose your path'), findsOneWidget);
    expect(find.text('Student Login'), findsOneWidget);
  });
}
