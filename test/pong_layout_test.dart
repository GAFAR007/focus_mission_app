/**
 * WHAT: Viewport and accessibility checks for the dedicated Pong arena.
 * WHY: Active rallies must fit laptops and phones without scrolling.
 * HOW: Render real arena widgets with server fixtures at all requested sizes.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_mission_app/features/student/presentation/pong_arena_screen.dart';
import 'pong_test.dart' show FakePongApi, frame;

void main() {
  for (final size in [
    const Size(1920, 1080),
    const Size(1366, 768),
    const Size(1280, 800),
    const Size(1024, 768),
    const Size(768, 1024),
    const Size(390, 844),
  ]) {
    testWidgets('arena fits ${size.width} x ${size.height}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = frame();
      data['state']['powerPool'] = ['rush'];
      final api = FakePongApi(data);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: PongArenaScreen(token: 'test', handle: 'g', api: api),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final court = tester.getRect(find.byKey(const ValueKey('pong-court')));
      expect(court.height, greaterThan(court.width));
      expect(court.bottom, lessThan(size.height));
      expect(court.height, greaterThan(size.height * .58));
      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull);
      final output = Platform.environment['PONG_QA_OUTPUT'];
      if (output != null) {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/arena-${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytes(png!.buffer.asUint8List());
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
