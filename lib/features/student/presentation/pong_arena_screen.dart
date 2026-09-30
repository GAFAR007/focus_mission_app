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
import '../../../core/constants/app_palette.dart';
import '../../../core/utils/pong_api.dart';
import '../../../shared/models/pong_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import 'pong_game_controller.dart';

class PongArenaScreen extends StatefulWidget {
  const PongArenaScreen({
    super.key,
    required this.token,
    required this.handle,
    this.api,
  });
  final String token, handle;
  final PongApi? api;
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _game.move(direction: 0);
      if (_game.frame?.computer == true && _game.frame?.ended == false) {
        _game.control('pause').catchError((_) {});
      }
    }
  }

  Future<void> _leave({bool restart = false}) async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      if (_game.frame?.ended != true) await _game.control('leave');
      if (!mounted) return;
      setState(() => _allowPop = true);
      // WHY: PopScope must rebuild with permission before Navigator can pop.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.pop(context, restart ? _game.frame?.level : null);
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
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyS,
    ];
    if (!keys.contains(event.logicalKey)) return KeyEventResult.ignored;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final up =
        pressed.contains(LogicalKeyboardKey.arrowUp) ||
        pressed.contains(LogicalKeyboardKey.keyW);
    final down =
        pressed.contains(LogicalKeyboardKey.arrowDown) ||
        pressed.contains(LogicalKeyboardKey.keyS);
    _game.move(
      direction: up == down
          ? 0
          : up
          ? -1
          : 1,
    );
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    child: FocusScaffold(
      child: AnimatedBuilder(
        animation: _game,
        builder: (context, _) {
          final frame = _game.frame;
          return Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _key,
            onFocusChange: (focused) {
              if (!focused) _game.move(direction: 0);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(
                      1100,
                      math.max(
                        360,
                        // Reserve space for score, progress, controls and footer.
                        (MediaQuery.sizeOf(context).height -
                                (frame?.computer == true ? 410 : 360)) /
                            .56,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.sports_esports_outlined,
                            color: AppPalette.navy,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pong Challenge',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          TextButton(
                            onPressed: _leaving ? null : _leave,
                            child: const Text('Exit game'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (frame == null) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 24),
                        const Text('Connecting to your game…'),
                      ] else ...[
                        Text(
                          frame.computer
                              ? 'Level ${frame.level} · Get ${frame.goal} returns'
                              : 'Student battle · First to 7',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${frame.players[0]['name']}${frame.side == 0 ? ' · You' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.navy,
                                ),
                              ),
                            ),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                '${frame.score[0]} : ${frame.score[1]}',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${frame.players[1]['name']}${frame.side == 1 ? ' · You' : ''}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (frame.computer) ...[
                          LinearProgressIndicator(
                            value: (frame.returns / frame.goal).clamp(0, 1),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${frame.returns} / ${frame.goal} returns',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                        ],
                        LayoutBuilder(
                          builder: (context, constraints) => GestureDetector(
                            onPanStart: (_) => _focus.requestFocus(),
                            onPanUpdate: frame.ended
                                ? null
                                : (event) => _game.move(
                                    targetY:
                                        event.localPosition.dy /
                                        (constraints.maxWidth * .56) *
                                        560,
                                  ),
                            onTapDown: frame.ended
                                ? null
                                : (event) {
                                    _focus.requestFocus();
                                    _game.move(
                                      targetY:
                                          event.localPosition.dy /
                                          (constraints.maxWidth * .56) *
                                          560,
                                    );
                                  },
                            child: Semantics(
                              label:
                                  'Pong arena. Your paddle is on the ${frame.side == 0 ? 'left' : 'right'}. Use W and S, arrow keys, drag, or the move buttons.',
                              child: AspectRatio(
                                aspectRatio: 1000 / 560,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CustomPaint(
                                        painter: PongArenaPainter(
                                          frame: frame,
                                          previous: _game.previousFrame,
                                          receivedAt: _game.receivedAt,
                                          clock: _paintClock,
                                          reducedMotion:
                                              MediaQuery.disableAnimationsOf(
                                                context,
                                              ),
                                        ),
                                      ),
                                      if (frame.waiting && !frame.ended)
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
                                      if (frame.ended)
                                        _overlay(
                                          _endTitle(frame),
                                          frame.reason.isNotEmpty
                                              ? frame.reason
                                              : 'Longest rally: ${frame.longestRally} · Progress saved',
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!frame.ended) ...[
                          Text(
                            'Your paddle: ${frame.side == 0 ? 'left · blue' : 'right · warm gold'}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _moveButton(
                                'Move up',
                                Icons.arrow_upward,
                                -1,
                                frame,
                              ),
                              _moveButton(
                                'Move down',
                                Icons.arrow_downward,
                                1,
                                frame,
                              ),
                              if (frame.computer)
                                OutlinedButton(
                                  onPressed: () {
                                    _game
                                        .control(
                                          frame.paused ? 'resume' : 'pause',
                                        )
                                        .catchError((_) {});
                                    _focus.requestFocus();
                                  },
                                  child: Text(
                                    frame.paused ? 'Resume' : 'Pause',
                                  ),
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
                          const SizedBox(height: 10),
                          const Text(
                            'W / S or ↑ / ↓ · Drag or use the buttons',
                            textAlign: TextAlign.center,
                          ),
                        ] else
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              if (frame.computer && frame.status == 'complete')
                                FilledButton(
                                  onPressed: _leaving
                                      ? null
                                      : () => _leave(restart: true),
                                  child: const Text('Play again'),
                                ),
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
                      if (_game.error != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _game.error!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
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
  );
  Widget _moveButton(
    String label,
    IconData icon,
    int direction,
    PongFrame frame,
  ) => Listener(
    onPointerDown: (_) {
      _focus.requestFocus();
      _game.move(direction: direction);
    },
    onPointerUp: (_) => _game.move(direction: 0),
    onPointerCancel: (_) => _game.move(direction: 0),
    child: FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size(150, 56)),
      onPressed: () {
        final y = (frame.state['paddles'][frame.side] as num).toDouble();
        _game.move(targetY: y + direction * 60);
      },
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

class PongArenaPainter extends CustomPainter {
  PongArenaPainter({
    required this.frame,
    required this.previous,
    required this.receivedAt,
    required Listenable clock,
    required this.reducedMotion,
  }) : super(repaint: clock);
  final PongFrame frame;
  final PongFrame? previous;
  final DateTime receivedAt;
  final bool reducedMotion;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 1000, size.height / 560);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1000, 560),
      Paint()..color = const Color(0xFF10213B),
    );
    final guide = Paint()
      ..color = const Color(0xFF355174)
      ..strokeWidth = 2;
    for (double y = 20; y < 560; y += 30) {
      canvas.drawLine(Offset(500, y), Offset(500, y + 13), guide);
    }
    final state = frame.state;
    if (state['arena'] == 'speed') {
      final zone = Paint()..color = const Color(0x223DD9C6);
      canvas.drawRect(const Rect.fromLTWH(270, 0, 80, 560), zone);
      canvas.drawRect(const Rect.fromLTWH(650, 0, 80, 560), zone);
    }
    if (state['arena'] == 'gravity') {
      canvas.drawCircle(
        const Offset(500, 280),
        155,
        Paint()..color = const Color(0x226B91FF),
      );
    }
    for (final line in state['barriers'] as List) {
      canvas.drawLine(
        Offset((line[0] as num).toDouble(), (line[1] as num).toDouble()),
        Offset((line[2] as num).toDouble(), (line[3] as num).toDouble()),
        Paint()
          ..color = const Color(0xFF91AACB)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
    final fraction =
        (DateTime.now().difference(receivedAt).inMicroseconds / 50000).clamp(
          0.0,
          1.0,
        );
    double coordinate(PongJson value, String key) =>
        (value[key] as num).toDouble();
    final ball = pongMap(state['ball']),
        before = previous == null ? ball : pongMap(previous!.state['ball']);
    final jump = (coordinate(ball, 'x') - coordinate(before, 'x')).abs() > 100;
    final x = lerpDouble(
      coordinate(before, 'x'),
      coordinate(ball, 'x'),
      jump ? 1 : fraction,
    )!;
    final y = lerpDouble(
      coordinate(before, 'y'),
      coordinate(ball, 'y'),
      jump ? 1 : fraction,
    )!;
    if (!reducedMotion && !jump && !frame.waiting && !frame.paused) {
      canvas.drawLine(
        Offset(coordinate(before, 'x'), coordinate(before, 'y')),
        Offset(x, y),
        Paint()
          ..color = const Color(0x557AB4FF)
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(Offset(x, y), 8, Paint()..color = Colors.white);
    for (int side = 0; side < 2; side++) {
      final height = (state['paddleHeights'][side] as num).toDouble();
      final center = (state['paddles'][side] as num).toDouble();
      final prior = previous == null
          ? center
          : (previous!.state['paddles'][side] as num).toDouble();
      final py = lerpDouble(prior, center, fraction)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(side == 0 ? 28 : 972, py),
            width: 14,
            height: height,
          ),
          const Radius.circular(7),
        ),
        Paint()
          ..color = side == 0
              ? const Color(0xFF6EC5FF)
              : const Color(0xFFFFCE85),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1, 1, 998, 558),
        const Radius.circular(24),
      ),
      Paint()
        ..color = const Color(0xFF53749E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, 2),
    );
  }

  @override
  bool shouldRepaint(PongArenaPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.reducedMotion != reducedMotion;
}
