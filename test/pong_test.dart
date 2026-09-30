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
    'paddles': [280, 280],
    'paddleHeights': [150, 132],
    'score': status == 'complete' ? [7, 4] : [0, 0],
    'returns': 0,
    'goal': computer ? 5 : 7,
    'longestRally': 10,
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
    double? targetY,
  ) async {
    inputs.add({'direction': direction, 'targetY': targetY});
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
    final hint = find.text('W / S or ↑ / ↓ · Drag or use the buttons');
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
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(milliseconds: 210));
      expect(api.inputs.any((input) => input['direction'] == -1), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(milliseconds: 210));
      expect(api.inputs.last['direction'], 0);
      expect(find.text('Move up'), findsOneWidget);
      expect(find.text('Move down'), findsOneWidget);
      expect(find.text('0 : 0'), findsOneWidget);
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
      expect(find.text('7 : 4'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
