/**
 * WHAT: Accessible one-ball Pong arena with solo and student battle controls.
 * WHY: Students need a clear goal, readable score and calm reconnect feedback.
 * HOW: Paint interpolated server snapshots; send only keyboard/touch/drag input.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/pong_api.dart';
import '../../../shared/models/pong_models.dart';
import 'pong_theme.dart';
import 'pong_audio_controls.dart';
import 'pong_game_controller.dart';
import 'pong_court_geometry.dart';
import 'pong_audio.dart';

class PongArenaScreen extends StatefulWidget {
  const PongArenaScreen({
    super.key,
    required this.token,
    required this.handle,
    this.api,
    this.audio,
  });
  final String token, handle;
  final PongApi? api;
  final PongAudio? audio;
  @override
  State<PongArenaScreen> createState() => _PongArenaScreenState();
}

class _PongArenaScreenState extends State<PongArenaScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final PongApi _api = widget.api ?? PongApi(widget.token);
  late final PongGameController _game = PongGameController(_api, widget.handle);
  late final AnimationController _paintClock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  final FocusNode _focus = FocusNode(debugLabel: 'Pong paddle controls');
  bool _leaving = false, _allowPop = false;
  final Set<int> _pointerButtons = {};
  late final PongAudio _audio = widget.audio ?? PongAudio();
  void _sound() {
    final frame = _game.frame;
    if (frame != null) {
      _audio.select(
        frame.ended
            ? null
            : PongTrack.match(
                power: !frame.computer && frame.ruleset == 'power',
                level: frame.level,
              ),
        match: frame.handle,
      );
      _audio.suspend(frame.paused || frame.waiting || _game.error != null);
      _audio.events(pongRows(frame.state['events']));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game.addListener(_sound);
    if (widget.audio == null) _audio.loadPreferences();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _audio.background(state != AppLifecycleState.resumed);
    if (state != AppLifecycleState.resumed) {
      _game.move(direction: 0, forward: 0);
      if (_game.frame?.computer == true && _game.frame?.ended == false) {
        _game.control('pause').catchError((_) {});
      }
    }
  }

  Future<void> _leave({bool restart = false, bool next = false}) async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      if (_game.frame?.ended != true) await _game.control('leave');
      if (!mounted) return;
      setState(() => _allowPop = true);
      // WHY: PopScope must rebuild with permission before Navigator can pop.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.pop(
        context,
        next
            ? (_game.frame!.level + 1)
            : restart
            ? _game.frame?.level
            : null,
      );
    } catch (_) {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _rematch(PongFrame frame) async {
    setState(() => _leaving = true);
    try {
      await _api.challenge(
        frame.players[1 - frame.side]['handle'] as String,
        rematchOf: frame.handle,
        ruleset: frame.ruleset,
      );
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _leaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    const keys = [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.keyW,
    ];
    if (!keys.contains(event.logicalKey)) return KeyEventResult.ignored;
    _audio.activate();
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final left =
        pressed.contains(LogicalKeyboardKey.arrowLeft) ||
        pressed.contains(LogicalKeyboardKey.keyA);
    final right =
        pressed.contains(LogicalKeyboardKey.arrowRight) ||
        pressed.contains(LogicalKeyboardKey.keyD);
    final rush =
        pressed.contains(LogicalKeyboardKey.arrowUp) ||
        pressed.contains(LogicalKeyboardKey.keyW);
    _game.move(
      direction: PongCourt.direction(
        left == right
            ? 0
            : left
            ? -1
            : 1,
        _game.frame?.side ?? 0,
      ),
      forward: rush ? 1 : 0,
    );
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.removeListener(_sound);
    if (widget.audio == null) {
      _audio.dispose();
    } else {
      _audio.suspend(false);
      _audio.select(PongTrack.city);
    }
    if (const bool.fromEnvironment('PONG_DIAGNOSTICS')) {
      debugPrint('[pong motion] ${_game.diagnostics.summary}');
    }
    assert(() {
      debugPrint('[pong motion] ${_game.diagnostics.summary}');
      return true;
    }());
    _game.dispose();
    _api.close();
    _paintClock.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: PongScaffold(
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _key,
        onFocusChange: (focused) {
          if (!focused) _game.move(direction: 0, forward: 0);
        },
        child: Listener(
          onPointerDown: (_) => _audio.activate(),
          child: AnimatedBuilder(
            animation: _game,
            builder: (context, _) {
              final frame = _game.frame;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'FOCUS MISSION · CUP PONG',
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        PongAudioControls(audio: _audio),
                        IconButton(
                          tooltip: 'How to play',
                          onPressed: () => _help(frame),
                          icon: const Icon(Icons.help_outline),
                        ),
                        IconButton(
                          tooltip: 'Exit game',
                          onPressed: _leaving ? null : _leave,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (frame == null)
                      const Expanded(
                        child: Center(child: Text('Connecting to your game…')),
                      )
                    else ...[
                      Text(
                        frame.computer
                            ? 'LEVEL ${frame.level.toString().padLeft(2, '0')} · ${frame.returns} / ${frame.goal} returns'
                            : '${frame.ruleset == 'power' ? 'Power Battle' : 'Classic'} · First to 7',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      if (frame.computer)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: LinearProgressIndicator(
                            value: (frame.returns / frame.goal).clamp(0, 1),
                            minHeight: 3,
                          ),
                        ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // The court uses the full available height. A vertical display
                            // projection may widen on laptops; canonical physics is unchanged.
                            final width = math.min(
                              constraints.maxWidth,
                              constraints.maxHeight * .70,
                            );
                            return Center(
                              child: SizedBox(
                                width: width,
                                height: constraints.maxHeight,
                                child: Column(
                                  children: [
                                    _player(frame, 1 - frame.side, false),
                                    Expanded(
                                      child: GestureDetector(
                                        onPanStart: (_) =>
                                            _focus.requestFocus(),
                                        onPanUpdate: frame.ended
                                            ? null
                                            : (e) => _game.move(
                                                direction: 0,
                                                targetY: PongCourt.target(
                                                  e.localPosition.dx / width,
                                                  frame.side,
                                                ),
                                              ),
                                        onTapDown: frame.ended
                                            ? null
                                            : (e) {
                                                _focus.requestFocus();
                                                _game.move(
                                                  direction: 0,
                                                  targetY: PongCourt.target(
                                                    e.localPosition.dx / width,
                                                    frame.side,
                                                  ),
                                                );
                                              },
                                        child: Semantics(
                                          label:
                                              'Pong arena. You defend the bottom. Use A and D, left and right arrows, or drag horizontally. Hold W or up for Forward Rush when active.',
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                RepaintBoundary(
                                                  child: CustomPaint(
                                                    key: const ValueKey(
                                                      'pong-court',
                                                    ),
                                                    painter: PongArenaPainter(
                                                      game: _game,
                                                      initialFrame: frame,
                                                      clock: _paintClock,
                                                      reducedMotion:
                                                          MediaQuery.disableAnimationsOf(
                                                            context,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                if (frame.waiting &&
                                                    !frame.ended)
                                                  _overlay(
                                                    'Waiting for connection…',
                                                    '${frame.reconnectSeconds}s to reconnect · No points awarded',
                                                  ),
                                                if (frame.paused &&
                                                    !frame.waiting &&
                                                    !frame.ended)
                                                  _overlay(
                                                    'Paused',
                                                    'Resume when you are ready',
                                                  ),
                                                if (frame.state['phase'] ==
                                                        'ready' &&
                                                    !frame.paused &&
                                                    !frame.waiting &&
                                                    !frame.ended)
                                                  IgnorePointer(
                                                    child: _overlay(
                                                      'READY',
                                                      frame.computer
                                                          ? 'Level ${frame.level} · Defend your baseline'
                                                          : '${frame.players[frame.side]['name']} vs ${frame.players[1 - frame.side]['name']}',
                                                    ),
                                                  ),
                                                if (frame.ended)
                                                  _overlay(
                                                    _endTitle(frame),
                                                    frame.reason.isNotEmpty
                                                        ? frame.reason
                                                        : '${frame.computer ? '${frame.returns} / ${frame.goal} returns · ' : ''}Longest rally: ${frame.longestRally} · Progress saved',
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    _player(frame, frame.side, true),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_game.error != null)
                        Text(
                          _game.error!,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      Text(
                        _boostText(frame),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (!frame.ended) ...[
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _moveButton('Left', Icons.arrow_back, -1, frame),
                            if ((frame.state['powerPool'] as List? ?? [])
                                .contains('rush'))
                              _rushButton(frame),
                            _moveButton('Right', Icons.arrow_forward, 1, frame),
                            if (frame.computer)
                              TextButton(
                                onPressed: () {
                                  _game
                                      .control(
                                        frame.paused ? 'resume' : 'pause',
                                      )
                                      .catchError((_) {});
                                  _focus.requestFocus();
                                },
                                child: Text(frame.paused ? 'Resume' : 'Pause'),
                              ),
                          ],
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Rally ${frame.state['rally'] ?? 0} · ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'A / D or ← / → · Drag to move',
                              style: TextStyle(fontSize: 12),
                            ),
                            if (frame.computer)
                              TextButton(
                                onPressed: _leaving
                                    ? null
                                    : () => _leave(restart: true),
                                child: const Text('Restart'),
                              ),
                          ],
                        ),
                      ] else
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (frame.computer &&
                                frame.status == 'complete') ...[
                              if (frame.state['completed'] == true &&
                                  frame.level < 15)
                                FilledButton(
                                  onPressed: _leaving
                                      ? null
                                      : () => _leave(next: true),
                                  child: Text(
                                    'Next · Level ${frame.level + 1}',
                                  ),
                                ),
                              FilledButton(
                                onPressed: _leaving
                                    ? null
                                    : () => _leave(restart: true),
                                child: const Text('Play again'),
                              ),
                            ],
                            if (!frame.computer && frame.status == 'complete')
                              FilledButton(
                                onPressed: _leaving
                                    ? null
                                    : () => _rematch(frame),
                                child: const Text('Request rematch'),
                              ),
                            OutlinedButton(
                              onPressed: _leaving ? null : _leave,
                              child: Text(
                                frame.computer
                                    ? 'Return to levels'
                                    : 'Return to lobby',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  Widget _player(PongFrame frame, int side, bool local) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${frame.players[side]['name']} · ${local ? 'You · Bottom' : 'Opponent · Top'}',
            key: ValueKey(local ? 'pong-local-player' : 'pong-opponent'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: local ? PongColors.cyan : PongColors.coral,
            ),
          ),
        ),
        Text(
          '${frame.score[side]}',
          key: ValueKey(local ? 'pong-local-score' : 'pong-opponent-score'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
  String _boostText(PongFrame frame) {
    if (!frame.computer && frame.ruleset != 'power') {
      return 'Classic · No boosts · Defend your baseline';
    }
    if (frame.effects.length <= frame.side) {
      return 'Defend the bottom · Return the ball';
    }
    final boosts = frame.effects[frame.side];
    final items = pongRows(
      boosts['active'],
    ).map((e) => '${pongPowerLabel(e['type'])} ${e['seconds']}s').toList();
    if (boosts['slot'] != null) {
      final slot = pongMap(boosts['slot']);
      items.add('${pongPowerLabel(slot['type'])} READY ${slot['seconds']}s');
    }
    return items.isEmpty
        ? 'Defend the bottom · Catch boosts with your paddle'
        : items.join(' · ');
  }

  Widget _rushButton(PongFrame frame) => Listener(
    onPointerDown: frame.rushReady
        ? (_) {
            _focus.requestFocus();
            _game.move(forward: 1);
          }
        : null,
    onPointerUp: (_) => _game.move(forward: 0),
    onPointerCancel: (_) => _game.move(forward: 0),
    child: OutlinedButton(
      onPressed: frame.rushReady ? () {} : null,
      style: OutlinedButton.styleFrom(minimumSize: const Size(90, 48)),
      child: const Text('Hold Rush'),
    ),
  );
  void _help(PongFrame? frame) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Defend your baseline'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Move left or right. Edges make angled shots; moving as you hit adds speed and spin. Catch a drop with your paddle to use it.',
                ),
                const SizedBox(height: 12),
                for (final type in (frame?.state['powerPool'] as List? ?? []))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '${pongPowerLabel(type)} — ${pongPowerDescription(type)}',
                    ),
                  ),
                const Text(
                  'One stored shot or shield at a time. Hold W, ↑ or Hold Rush while Forward Rush is active. Release to retreat.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  String _endTitle(PongFrame frame) {
    if (frame.status != 'complete') return 'Game ended';
    if (frame.computer) {
      return frame.state['completed'] == true
          ? 'Level complete!'
          : 'Nice practice. Try again!';
    }
    return '${frame.players[frame.state['winner'] as int]['name']} wins';
  }

  Widget _overlay(String title, String subtitle) => ColoredBox(
    color: const Color(0xCC0C1B35),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _moveButton(
    String label,
    IconData icon,
    int direction,
    PongFrame frame,
  ) => Listener(
    onPointerDown: (_) {
      _pointerButtons.add(direction);
      _focus.requestFocus();
      _game.move(direction: PongCourt.direction(direction, frame.side));
    },
    onPointerUp: (_) {
      _game.move(direction: 0);
      // Material's tap callback follows pointer-up. Do not also enqueue a step
      // from an older server position after a held pointer has just stopped.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pointerButtons.remove(direction),
      );
    },
    onPointerCancel: (_) {
      _pointerButtons.remove(direction);
      _game.move(direction: 0);
    },
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(80, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: () {
        if (_pointerButtons.contains(direction)) return;
        final y = _game.localPaddleAt(_game.now());
        _game.move(
          direction: 0,
          targetY: y + PongCourt.direction(direction, frame.side) * 60,
        );
      },
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

String pongPowerLabel(dynamic type) => switch (type) {
  'speed' => '⚡ Speed',
  'wide' => '↔ Wide Paddle',
  'power' => '🔥 Power Shot',
  'shield' => '◇ Shield',
  'rush' => '↑ Forward Rush',
  'curve' => '↝ Curve',
  'focus' => '◷ Focus',
  _ => '',
};
String pongPowerDescription(dynamic type) => switch (type) {
  'speed' => 'Move 30% faster for 5 seconds.',
  'wide' => 'A wider paddle for 6 seconds.',
  'power' => 'Your next hit gets a capped speed boost. Use within 8 seconds.',
  'shield' => 'Saves one missed ball. Lasts up to 10 seconds.',
  'rush' => 'Move into your half for 4 seconds.',
  'curve' => 'Your next hit bends. Use within 8 seconds.',
  'focus' => 'Slows the incoming ball in your half for 3 seconds.',
  _ => '',
};

class PongArenaPainter extends CustomPainter {
  PongArenaPainter({
    required this.game,
    required this.initialFrame,
    required Listenable clock,
    required this.reducedMotion,
  }) : super(repaint: clock);
  final PongGameController game;
  final PongFrame initialFrame;
  final bool reducedMotion;
  @override
  void paint(Canvas canvas, Size size) {
    // WHY: The animation clock reads buffered server snapshots directly, so
    // 50 ms game frames do not rebuild the surrounding learner screen.
    final now = game.now();
    game.diagnostics.paint(now);
    final sample = game.renderSampleAt(now);
    final frame = sample?.current ?? game.frame ?? initialFrame;
    final previous = sample?.previous ?? game.previousFrame;
    final scaleX = size.width / PongCourt.width;
    final scaleY = size.height / PongCourt.height;
    canvas.scale(scaleX, scaleY);
    // The court projection expands to the viewport, but a ball stays round.
    void circle(Offset center, double radius, Paint paint) => canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 2 * scaleY / scaleX,
        height: radius * 2,
      ),
      paint,
    );
    Offset point(double x, double y) =>
        PongCourt.project(Offset(x, y), frame.side);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 560, 1000),
      Paint()..color = const Color(0xFF0C1928),
    );
    final grid = Paint()
      ..color = const Color(0x12389CBE)
      ..strokeWidth = 1;
    for (double x = 28; x < 560; x += 56) {
      canvas.drawLine(Offset(x, 0), Offset(x, 1000), grid);
    }
    for (double y = 50; y < 1000; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(560, y), grid);
    }
    final guide = Paint()
      ..color = const Color(0xFF355174)
      ..strokeWidth = 2;
    for (double x = 20; x < 560; x += 32) {
      canvas.drawLine(Offset(x, 500), Offset(x + 14, 500), guide);
    }
    circle(const Offset(280, 500), 60, guide..style = PaintingStyle.stroke);
    final state = frame.state;
    if (state['arena'] == 'speed') {
      for (final y in [270.0, 650.0]) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, 560, 80),
          Paint()..color = const Color(0x183DD9C6),
        );
      }
    }
    if (state['arena'] == 'gravity') {
      circle(
        const Offset(280, 500),
        155,
        Paint()..color = const Color(0x226B91FF),
      );
    }
    for (final line in state['barriers'] as List) {
      canvas.drawLine(
        point((line[0] as num).toDouble(), (line[1] as num).toDouble()),
        point((line[2] as num).toDouble(), (line[3] as num).toDouble()),
        Paint()
          ..color = const Color(0xFF91AACB)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
    final fraction = sample?.fraction ?? 1.0;
    double value(PongJson v, String key) => (v[key] as num).toDouble();
    final ball = pongMap(state['ball']),
        before = previous == null ? ball : pongMap(previous.state['ball']);
    final jump =
        (value(ball, 'x') - value(before, 'x')).abs() > 100 ||
        (value(ball, 'y') - value(before, 'y')).abs() > 100;
    final center = point(
      lerpDouble(value(before, 'x'), value(ball, 'x'), jump ? 1 : fraction)!,
      lerpDouble(value(before, 'y'), value(ball, 'y'), jump ? 1 : fraction)!,
    );
    final intensity = PongCourt.intensity(
      (state['ballSpeed'] as num? ?? 220).toDouble(),
      (state['maxSpeed'] as num? ?? 580).toDouble(),
    );
    final moving =
        !reducedMotion &&
        !jump &&
        !frame.waiting &&
        !frame.paused &&
        !frame.ended;
    final hot = state['hot'] == true;
    final ballColor = hot ? const Color(0xFFFFDF99) : Colors.white;
    final velocity = state['ballVelocity'] is Map
        ? pongMap(state['ballVelocity'])
        : {
            'x': (value(ball, 'x') - value(before, 'x')) / .05,
            'y': (value(ball, 'y') - value(before, 'y')) / .05,
          };
    if (moving && intensity > .5) {
      final trailLength = 18 + 85 * intensity * intensity;
      final speed = math.max(
        1.0,
        math.sqrt(
          math.pow(value(velocity, 'x'), 2) + math.pow(value(velocity, 'y'), 2),
        ),
      );
      final tail = point(
        lerpDouble(value(before, 'x'), value(ball, 'x'), fraction)! -
            value(velocity, 'x') * trailLength / speed,
        lerpDouble(value(before, 'y'), value(ball, 'y'), fraction)! -
            value(velocity, 'y') * trailLength / speed,
      );
      final trail = center - tail;
      final vector = trail.distance > .01
          ? trail / trail.distance
          : Offset.zero;
      final length = 18 + 85 * intensity * intensity;
      canvas.drawLine(
        center - vector * length,
        center,
        Paint()
          ..color = (hot ? Colors.orangeAccent : const Color(0xFF8CCBFF))
              .withValues(alpha: .28)
          ..strokeWidth = 5 + intensity * 7
          ..strokeCap = StrokeCap.round,
      );
      for (int i = 1; i <= (intensity * 5).floor(); i++) {
        circle(
          center - vector * (length * i / 5),
          3 - i * .35,
          Paint()..color = ballColor.withValues(alpha: .35),
        );
      }
    }
    final visualMs = lerpDouble(
      (previous?.state['elapsedMs'] as num? ?? 0).toDouble(),
      (state['elapsedMs'] as num? ?? 0).toDouble(),
      fraction,
    )!;
    for (final e in pongRows(state['events'])) {
      final age = (visualMs - (e['at'] as num)).toDouble();
      if (reducedMotion || age < 0 || age > 350 || !moving) continue;
      if (e['type'] == 'point') {
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 560, 1000),
          Paint()
            ..color = PongColors.cyan.withValues(alpha: .10 * (1 - age / 350)),
        );
      }
      final hit = point(value(e, 'x'), value(e, 'y'));
      final strength = e['type'] == 'strongHit' ? 1.0 : .6;
      for (int i = 0; i < 5; i++) {
        final angle = i * math.pi * 2 / 5;
        circle(
          hit + Offset(math.cos(angle), math.sin(angle)) * (10 + age * .055),
          2.5 * strength,
          Paint()
            ..color = const Color(
              0xFFFFDB9B,
            ).withValues(alpha: (1 - age / 350) * strength),
        );
      }
    }
    circle(center, 18, Paint()..color = ballColor.withValues(alpha: .08));
    circle(center, 9 + intensity * 1.5, Paint()..color = ballColor);
    for (int side = 0; side < 2; side++) {
      final width = (state['paddleHeights'][side] as num).toDouble();
      final py = (state['paddles'][side] as num).toDouble();
      final old = previous?.state;
      final priorY = old == null
          ? py
          : (old['paddles'][side] as num).toDouble();
      final depth = ((state['depths'] as List? ?? [0, 0])[side] as num)
          .toDouble();
      final priorDepth = ((old?['depths'] as List? ?? [0, 0])[side] as num)
          .toDouble();
      final local = side == frame.side;
      final interpolatedDepth = local
          ? game.localDepthAt(now)
          : lerpDouble(priorDepth, depth, fraction)!;
      final interpolatedY = local
          ? game.localPaddleAt(now)
          : lerpDouble(priorY, py, fraction)!;
      final location = point(
        side == 0 ? 28 + interpolatedDepth : 972 - interpolatedDepth,
        interpolatedY,
      );
      final color = local ? PongColors.cyan : PongColors.coral;
      final recentHit = pongRows(state['events']).any(
        (e) =>
            e['side'] == side &&
            ['hit', 'strongHit'].contains(e['type']) &&
            visualMs - (e['at'] as num) >= 0 &&
            visualMs - (e['at'] as num) < 150,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: location, width: width, height: 14),
          const Radius.circular(7),
        ),
        Paint()..color = moving && recentHit ? Colors.white : color,
      );
      final boosts = pongRows(state['boosts']);
      if (boosts.length > side && boosts[side]['slot']?['type'] == 'shield') {
        canvas.drawLine(
          Offset(16, local ? 990 : 10),
          Offset(544, local ? 990 : 10),
          Paint()
            ..color = color
            ..strokeWidth = 4,
        );
      }
    }
    for (final drop in pongRows(state['drops'])) {
      final center = point(value(drop, 'x'), value(drop, 'y'));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 152, height: 52),
          const Radius.circular(16),
        ),
        Paint()..color = const Color(0xFFEDF5FF),
      );
      final text = TextPainter(
        text: TextSpan(
          text: pongPowerLabel(
            drop['type'],
          ).replaceAll(' Paddle', '').replaceAll('Forward ', ''),
          style: const TextStyle(
            color: Color(0xFF10213B),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 144);
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
    final pulse = moving && intensity > .94
        ? .15 + .1 * math.sin((state['elapsedMs'] as num? ?? 0) / 180)
        : 0.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 2, 556, 996),
        const Radius.circular(24),
      ),
      Paint()
        ..color = Color.lerp(const Color(0xFF53749E), Colors.white, pulse)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(PongArenaPainter oldDelegate) =>
      oldDelegate.game != game ||
      oldDelegate.initialFrame != initialFrame ||
      oldDelegate.reducedMotion != reducedMotion;
}
