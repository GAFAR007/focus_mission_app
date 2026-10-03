/**
 * WHAT: Deterministic regressions for input discontinuities and network jitter.
 * WHY: The previous predictor jumped 52 units on press/release after an 80ms gap.
 * HOW: Inject a clock, deliver irregular authoritative snapshots, and sample at
 * display cadence. No client position is submitted as a result or collision.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mission_app/features/student/presentation/pong_game_controller.dart';
import 'package:focus_mission_app/shared/models/pong_models.dart';
import 'pong_test.dart' show FakePongApi, frame;

void main() {
  late DateTime clock;
  late FakePongApi api;
  late PongGameController game;
  Future<void> deliver(
    int elapsed, {
    double x = 500,
    double y = 280,
    double paddle = 280,
    String phase = 'playing',
    List<int> score = const [0, 0],
    bool paused = false,
    bool waiting = false,
    bool shield = false,
  }) async {
    final data = frame(waiting: waiting);
    data['paused'] = paused;
    data.remove('controlToken');
    data['state'].addAll({
      'elapsedMs': elapsed,
      'phase': phase,
      'ball': {'x': x, 'y': y},
      'score': score,
      'paddles': [paddle, paddle],
      'events': shield
          ? [
              {'id': 1, 'type': 'shield', 'at': elapsed, 'x': x, 'y': y},
            ]
          : [],
    });
    api.stream.add(PongFrame.fromJson(data));
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    clock = DateTime(2026);
    api = FakePongApi(frame());
    game = PongGameController(api, 'g', clock: () => clock);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    game.dispose();
    await api.stream.close();
  });

  test('press release and reversal preserve position at the input instant', () {
    clock = clock.add(const Duration(milliseconds: 80));
    final before = game.localPaddleAt(clock);
    game.move(direction: 1);
    expect(game.localPaddleAt(clock), before);
    clock = clock.add(const Duration(milliseconds: 16));
    final moved = game.localPaddleAt(clock);
    expect(moved - before, closeTo(10.4, .001));
    game.move(direction: 0);
    expect(game.localPaddleAt(clock), moved);
    clock = clock.add(const Duration(milliseconds: 16));
    expect(game.localPaddleAt(clock), moved);
    game.move(direction: -1);
    expect(game.localPaddleAt(clock), moved);
    clock = clock.add(const Duration(milliseconds: 16));
    expect(game.localPaddleAt(clock), lessThan(moved));
  });

  test(
    'small corrections are continuous and large desync snaps to truth',
    () async {
      game.move(direction: 1);
      clock = clock.add(const Duration(milliseconds: 50));
      final before = game.localPaddleAt(clock);
      await deliver(50, paddle: 300);
      expect(game.localPaddleAt(clock), closeTo(before, .001));
      game.move(direction: 0);
      clock = clock.add(const Duration(milliseconds: 16));
      expect((game.localPaddleAt(clock) - before).abs(), lessThan(2));
      await deliver(100, paddle: 100);
      expect(game.localPaddleAt(clock), 100);
    },
  );

  test(
    'touch target changes do not retroactively jump; stale prediction holds',
    () {
      clock = clock.add(const Duration(milliseconds: 80));
      final before = game.localPaddleAt(clock);
      game.move(targetY: 900, direction: 0);
      expect(game.localPaddleAt(clock), before);
      clock = clock.add(const Duration(milliseconds: 50));
      expect(game.localPaddleAt(clock), greaterThan(before));
      clock = clock.add(const Duration(seconds: 1));
      final held = game.localPaddleAt(clock);
      clock = clock.add(const Duration(seconds: 3));
      expect(game.localPaddleAt(clock), held);
      expect(held, inInclusiveRange(75, 485));
    },
  );

  test(
    'irregular 20Hz arrivals cannot rewind continuous ball travel',
    () async {
      var lastX = 500.0;
      var maxStep = 0.0;
      final arrivals = [
        0,
        55,
        105,
        180,
        205,
        265,
        305,
        355,
        410,
        450,
        505,
        565,
        610,
        655,
        710,
        760,
        805,
      ];
      var packet = 1;
      for (var ms = 0; ms <= 800; ms += 8) {
        clock = DateTime(2026).add(Duration(milliseconds: ms));
        while (packet < arrivals.length && arrivals[packet] <= ms) {
          await deliver(
            packet * 50,
            x: 500 + packet * 10,
            paddle: 280 + packet * 2,
          );
          packet++;
        }
        final sample = game.renderSampleAt(clock)!;
        final a = (sample.previous.state['ball']['x'] as num).toDouble();
        final b = (sample.current.state['ball']['x'] as num).toDouble();
        final x = a + (b - a) * sample.fraction;
        expect(x, greaterThanOrEqualTo(lastX));
        if (x - lastX > maxStep) maxStep = x - lastX;
        lastX = x;
        game.diagnostics.paint(clock);
      }
      expect(
        maxStep,
        lessThan(1.8),
      ); // 200 units/s at 8ms, including clock slew.
      expect(game.diagnostics.worstIntervalMs, greaterThan(50));
      expect(game.diagnostics.worstFrameMs, 8);
      expect(game.diagnostics.bufferDepthMs, greaterThan(0));
      final before = game.frame;
      await deliver(100, x: 520);
      expect(game.frame, same(before));
      expect(game.diagnostics.lateSnapshots, 1);
      await deliver(150, phase: 'ready');
      expect(game.frame, same(before));
      expect(game.diagnostics.lateSnapshots, 2);
    },
  );

  for (final boundary in ['score', 'serve', 'pause', 'waiting', 'shield']) {
    test(
      '$boundary clears interpolation without travelling across court',
      () async {
        clock = clock.add(const Duration(milliseconds: 50));
        await deliver(50, x: 520);
        game.renderSampleAt(clock);
        clock = clock.add(const Duration(milliseconds: 50));
        await deliver(
          100,
          x: 300,
          phase: boundary == 'serve' ? 'ready' : 'playing',
          score: boundary == 'score' ? [1, 0] : [0, 0],
          paused: boundary == 'pause',
          waiting: boundary == 'waiting',
          shield: boundary == 'shield',
        );
        final sample = game.renderSampleAt(clock)!;
        expect(sample.current.state['ball']['x'], 300);
        expect(sample.previous, same(sample.current));
      },
    );
  }
  test('display sampling cannot mutate authoritative state', () {
    final original = jsonEncode(game.frame!.state);
    game.move(direction: 1);
    for (var ms = 0; ms < 200; ms += 8) {
      clock = DateTime(2026).add(Duration(milliseconds: ms));
      game.localPaddleAt(clock);
      game.renderSampleAt(clock);
    }
    expect(jsonEncode(game.frame!.state), original);
    expect(
      api.inputs.every(
        (e) => !e.containsKey('score') && !e.containsKey('ball'),
      ),
      isTrue,
    );
  });
}
