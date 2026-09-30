/**
 * WHAT: Tests Pong API boundaries, disabled UI and accessible arena controls.
 * WHY: Game screens must not expose learning data or invent local results.
 * HOW: Mock HTTP commands and deliver authoritative frames to real widgets.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:focus_mission_app/core/utils/pong_api.dart';
import 'package:focus_mission_app/core/theme/app_theme.dart';
import 'package:focus_mission_app/shared/widgets/release_history_button.dart';
import 'package:focus_mission_app/shared/models/pong_models.dart';
import 'package:focus_mission_app/shared/widgets/pong_access_panel.dart';
import 'package:focus_mission_app/features/student/presentation/pong_home_screen.dart';
import 'package:focus_mission_app/features/student/presentation/pong_arena_screen.dart';
import 'package:focus_mission_app/features/student/presentation/pong_game_controller.dart';
import 'package:focus_mission_app/features/student/presentation/pong_court_geometry.dart';
import 'package:focus_mission_app/features/student/presentation/pong_lobby_screen.dart';

PongJson profile({bool enabled = true}) => {
  'access': {
    'enabled': enabled,
    'computer': true,
    'battles': true,
    'lobbyVisible': true,
  },
  'progress': {
    'highestUnlocked': 3,
    'completedLevels': [1, 2],
    'bestRally': 10,
    'computerWins': 2,
    'multiplayerWins': 1,
    'multiplayerLosses': 0,
    'matchesPlayed': 3,
  },
  'levels': [
    for (int i = 1; i <= 15; i++)
      {'level': i, 'name': 'Level $i', 'goal': i + 4, 'arena': 'plain'},
  ],
};
PongJson frame({
  String status = 'active',
  bool computer = true,
  bool waiting = false,
}) => {
  'handle': 'game-handle',
  'status': status,
  'reason': '',
  'side': 0,
  'players': [
    {'name': 'Ava A.', 'handle': 'ava-handle'},
    {'name': computer ? 'Computer' : 'Ben B.', 'handle': 'ben-handle'},
  ],
  'controlToken': 'controller-handle',
  'paused': false,
  'waiting': waiting,
  'reconnectSeconds': 18,
  'state': {
    'mode': computer ? 'computer' : 'pvp',
    'level': computer ? 1 : 0,
    'phase': status == 'complete' ? 'complete' : 'playing',
    'ball': {'x': 500, 'y': 280},
    'ballVelocity': {'x': 220, 'y': 0},
    'ballSpeed': 220,
    'maxSpeed': 390,
    'paddles': [280, 280],
    'paddleHeights': [150, 132],
    'depths': [0, 0],
    'score': status == 'complete' ? [7, 4] : [0, 0],
    'returns': 0,
    'goal': computer ? 5 : 7,
    'longestRally': 10,
    'elapsedMs': 0,
    'barriers': [],
    'arena': 'plain',
    'completed': status == 'complete',
    'winner': status == 'complete' ? 0 : null,
  },
};

class FakePongApi extends PongApi {
  FakePongApi(this.initial) : super('test-token');
  final PongJson initial;
  final inputs = <PongJson>[];
  final controls = <String>[];
  late final StreamController<PongFrame> stream = StreamController<PongFrame>(
    onListen: () =>
        scheduleMicrotask(() => stream.add(PongFrame.fromJson(initial))),
  );
  @override
  Stream<PongFrame> frames(String handle) => stream.stream;
  @override
  Future<void> input(
    String handle,
    String controlToken,
    int seq,
    int direction,
    double? targetY, {
    int forward = 0,
  }) async {
    inputs.add({
      'direction': direction,
      'targetY': targetY,
      'forward': forward,
    });
  }

  @override
  Future<void> control(String handle, String action) async {
    controls.add(action);
  }

  @override
  void close() {
    stream.close();
    super.close();
  }
}

void main() {
  test(
    'local paddle prediction moves immediately and eases small server corrections',
    () async {
      final data = frame();
      data['state']['boosts'] = [
        {'active': [], 'slot': null},
        {'active': [], 'slot': null},
      ];
      final api = FakePongApi(data);
      final game = PongGameController(api, 'g');
      addTearDown(game.dispose);
      await Future<void>.delayed(Duration.zero);

      game.receivedAt = DateTime.now().subtract(
        const Duration(milliseconds: 100),
      );
      game.move(direction: 1);
      final predicted = game.localPaddleAt(DateTime.now());
      expect(predicted, closeTo(345, 2));

      final corrected = frame();
      corrected['state']['paddles'][0] = 338;
      corrected['state']['depths'] = [0, 0];
      corrected['state']['boosts'] = data['state']['boosts'];
      api.stream.add(PongFrame.fromJson(corrected));
      await Future<void>.delayed(Duration.zero);
      final reconciled = game.localPaddleAt(DateTime.now());
      expect(reconciled, inInclusiveRange(338, 360));
      expect(
        game.localPaddleAt(
          DateTime.now().add(const Duration(milliseconds: 80)),
        ),
        greaterThan(reconciled),
      );
      await api.stream.close();
    },
  );

  test(
    'Forward Rush depth preview follows a held input and stays bounded',
    () async {
      final data = frame();
      data['state']['depths'] = [0, 0];
      data['state']['powerPool'] = ['rush'];
      data['state']['boosts'] = [
        {
          'active': [
            {'type': 'rush', 'seconds': 4},
          ],
          'slot': null,
        },
        {'active': [], 'slot': null},
      ];
      final api = FakePongApi(data);
      final game = PongGameController(api, 'g');
      addTearDown(game.dispose);
      await Future<void>.delayed(Duration.zero);
      game.move(forward: 1);
      expect(
        game.localDepthAt(
          DateTime.now().add(const Duration(milliseconds: 100)),
        ),
        closeTo(17, 2),
      );
      expect(
        game.localDepthAt(DateTime.now().add(const Duration(seconds: 1))),
        lessThanOrEqualTo(110),
      );
      await api.stream.close();
    },
  );

  test(
    'remote ball and paddle render from buffered authoritative snapshots',
    () async {
      final api = FakePongApi(frame());
      final game = PongGameController(api, 'g');
      addTearDown(game.dispose);
      await Future<void>.delayed(Duration.zero);

      final second = frame();
      second['state']['elapsedMs'] = 50;
      second['state']['ball']['x'] = 550;
      second['state']['paddles'][1] = 300;
      api.stream.add(PongFrame.fromJson(second));
      await Future<void>.delayed(Duration.zero);
      final third = frame();
      third['state']['elapsedMs'] = 100;
      third['state']['ball']['x'] = 600;
      third['state']['paddles'][1] = 320;
      api.stream.add(PongFrame.fromJson(third));
      await Future<void>.delayed(Duration.zero);

      final sample = game.renderSampleAt(DateTime.now())!;
      expect(sample.previous.state['elapsedMs'], 0);
      expect(sample.current.state['elapsedMs'], 50);
      expect(sample.fraction, inInclusiveRange(.4, .8));
      final beforeX = (sample.previous.state['ball']['x'] as num).toDouble();
      final afterX = (sample.current.state['ball']['x'] as num).toDouble();
      final ballX = beforeX + (afterX - beforeX) * sample.fraction;
      expect(ballX, inInclusiveRange(520, 540));
      await api.stream.close();
    },
  );

  test(
    'vertical projection and inverse touch coordinates mirror each player fairly',
    () {
      expect(
        PongCourt.project(const Offset(28, 100), 0),
        const Offset(100, 972),
      );
      expect(
        PongCourt.project(const Offset(972, 460), 1),
        const Offset(100, 972),
      );
      expect(PongCourt.project(const Offset(972, 100), 0).dy, 28);
      expect(PongCourt.project(const Offset(28, 100), 1).dy, 28);
      for (final side in [0, 1]) {
        final canonical = PongCourt.target(.25, side);
        expect(
          PongCourt.project(Offset(side == 0 ? 28 : 972, canonical), side).dx,
          140,
        );
      }
      expect(PongCourt.direction(-1, 0), -1);
      expect(PongCourt.direction(-1, 1), 1);
      expect(
        PongCourt.intensity(200, 600),
        lessThan(PongCourt.intensity(500, 600)),
      );
      expect(PongCourt.intensity(2000, 600), 1);
    },
  );
  testWidgets(
    'second player is bottom with natural right and drag input on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = frame(computer: false);
      data['side'] = 1;
      final api = FakePongApi(data);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PongArenaScreen(token: 't', handle: 'g', api: api),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Ben B. · You · Bottom'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('pong-local-player'))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('pong-opponent'))).dy,
        ),
      );
      final court = tester.getRect(find.byKey(const ValueKey('pong-court')));
      expect(court.height, greaterThan(court.width));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.pump(const Duration(milliseconds: 210));
      expect(api.inputs.any((v) => v['direction'] == -1), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await tester.pump(const Duration(milliseconds: 210));
      expect(api.inputs.last['direction'], 0);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 90)),
      );
      await tester.tapAt(
        Offset(court.left + court.width * .75, court.bottom - 20),
      );
      await tester.pump(const Duration(milliseconds: 210));
      expect(api.inputs.last['targetY'], closeTo(140, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'rush is explicit, reduced motion is honoured and audio starts muted',
    (tester) async {
      final data = frame();
      data['state']['powerPool'] = ['rush'];
      data['state']['boosts'] = [
        {
          'active': [
            {'type': 'rush', 'seconds': 4},
          ],
          'slot': null,
        },
        {'active': [], 'slot': null},
      ];
      final api = FakePongApi(data);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              disableAnimations: true,
            ),
            child: PongArenaScreen(token: 't', handle: 'g', api: api),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byTooltip('Unmute game'), findsOneWidget);
      expect(find.textContaining('Forward Rush 4s'), findsOneWidget);
      final painter =
          tester
                  .widget<CustomPaint>(find.byKey(const ValueKey('pong-court')))
                  .painter
              as PongArenaPainter;
      expect(painter.reducedMotion, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await tester.pump(const Duration(milliseconds: 210));
      expect(api.inputs.any((v) => v['forward'] == 1), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      await tester.pump(const Duration(milliseconds: 210));
      expect(api.inputs.last['forward'], 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'Power Battle invitation labels and acceptance send the same explicit rules',
    (tester) async {
      final requests = <http.Request>[];
      final api = PongApi(
        'token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/me')) {
            final me = profile();
            me['access']['powerBattle'] = true;
            return http.Response(jsonEncode(me), 200);
          }
          if (request.url.path.endsWith('/lobby')) {
            return http.Response(
              jsonEncode({
                'powerBattle': true,
                'students': [],
                'challenges': [
                  {
                    'handle': 'invite',
                    'name': 'Ben B.',
                    'incoming': true,
                    'status': 'pending',
                    'expiresIn': 60,
                    'ruleset': 'power',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PongLobbyScreen(token: 't', api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Power Battle · Temporary boosts'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Accept'));
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      final accepted = requests.where((r) => r.method == 'POST').single;
      expect(jsonDecode(accepted.body), {
        'action': 'accept',
        'ruleset': 'power',
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('solo controls and instructions fit above the laptop footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1512, 805);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakePongApi(frame());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: PongArenaScreen(token: 'token', handle: 'game', api: api),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final hint = find.text('A / D or ← / → · Drag to move');
    expect(
      tester.getBottomLeft(hint).dy,
      lessThan(tester.getTopLeft(find.byType(ReleaseHistoryButton)).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('completed arena returns through the guarded route', (
    tester,
  ) async {
    final api = FakePongApi(frame(status: 'complete'));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PongArenaScreen(token: 'token', handle: 'game', api: api),
                ),
              ),
              child: const Text('Open game'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Return to levels'));
    await tester.tap(find.text('Return to levels'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Open game'), findsOneWidget);
    expect(find.text('Return to levels'), findsNothing);
  });
  test(
    'Pong API sends bearer identity and controls, never client results or school',
    () async {
      final requests = <http.Request>[];
      final api = PongApi(
        'synthetic-token',
        client: MockClient((request) async {
          requests.add(request);
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/me') ? profile() : {'accepted': true},
            ),
            200,
          );
        }),
      );
      final saved = await api.me();
      expect(saved.progress.highestUnlocked, 3);
      expect(saved.progress.completedLevels, [1, 2]);
      await api.input('game', 'control', 1, -1, null);
      expect(jsonDecode(requests.last.body), {
        'controlToken': 'control',
        'seq': 1,
        'direction': -1,
        'forward': 0,
      });
      expect(
        requests.every((request) => !request.url.toString().contains('token=')),
        isTrue,
      );
      api.close();
    },
  );
  test(
    'server permission errors remain actionable and preserve their code',
    () async {
      final api = PongApi(
        'token',
        client: MockClient(
          (_) async => http.Response(
            '{"message":"Your teacher has turned this game mode off.","code":"PONG_DISABLED"}',
            403,
          ),
        ),
      );
      await expectLater(
        api.computer(1),
        throwsA(
          isA<PongApiException>().having(
            (e) => e.code,
            'code',
            'PONG_DISABLED',
          ),
        ),
      );
      api.close();
    },
  );
  testWidgets(
    'disabled dashboard card preserves game progress and hides play actions',
    (tester) async {
      final api = PongApi(
        'token',
        client: MockClient(
          (_) async => http.Response(jsonEncode(profile(enabled: false)), 200),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PongDashboardCard(token: 'token', api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Level 3 / 15'), findsOneWidget);
      expect(
        find.textContaining('Your teacher has turned Pong off'),
        findsOneWidget,
      );
      expect(find.text('Play Computer'), findsNothing);
    },
  );
  testWidgets('enabled dashboard exposes both modes on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = PongApi(
      'token',
      client: MockClient(
        (_) async => http.Response(jsonEncode(profile()), 200),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PongDashboardCard(token: 'token', api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Play Computer'), findsOneWidget);
    expect(find.text('Play Student'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('staff access saves only the selected permission and student', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = PongApi(
      'token',
      client: MockClient((request) async {
        requests.add(request);
        final result = profile();
        if (request.method == 'PATCH') {
          result['access'] = {
            ...pongMap(result['access']),
            ...pongMap(jsonDecode(request.body)),
          };
        }
        return http.Response(jsonEncode(result), 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PongAccessPanel(
              token: 'token',
              studentId: 'student-a',
              api: api,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pong Challenge · Game access'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Student Battles'));
    await tester.pumpAndSettle();
    expect(requests.last.url.path.endsWith('/access/student-a'), isTrue);
    expect(jsonDecode(requests.last.body), {'battles': false});
    expect(find.textContaining('Student battles off'), findsOneWidget);
  });
  testWidgets(
    'arena supports keyboard release and large touch controls without local scoring',
    (tester) async {
      final api = FakePongApi(frame());
      await tester.pumpWidget(
        MaterialApp(
          home: PongArenaScreen(token: 'token', handle: 'game', api: api),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 210));
      expect(api.inputs.any((input) => input['direction'] == -1), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 210));
      expect(api.inputs.last['direction'], 0);
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'disconnect and completion show server state without inventing winners',
    (tester) async {
      final api = FakePongApi(frame(computer: false, waiting: true));
      await tester.pumpWidget(
        MaterialApp(
          home: PongArenaScreen(token: 'token', handle: 'game', api: api),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Waiting for connection…'), findsOneWidget);
      expect(find.textContaining('No points awarded'), findsOneWidget);
      api.stream.add(
        PongFrame.fromJson(frame(status: 'complete', computer: false)),
      );
      await tester.pump();
      expect(find.text('Ava A. wins'), findsOneWidget);
      expect(find.text('Request rematch'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
