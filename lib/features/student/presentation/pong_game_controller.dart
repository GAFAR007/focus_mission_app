/**
 * WHAT: Owns arena connection, reconnect and bounded paddle commands.
 * WHY: Network lifecycle must stay separate from game painting and controls.
 * HOW: Consume server frames, predict only the local paddle for display, throttle
 * input state, and reconcile against the authoritative simulation.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/utils/pong_api.dart';
import '../../../shared/models/pong_models.dart';

class PongGameController extends ChangeNotifier {
  PongGameController(this.api, this.handle) {
    connect();
    _heartbeat = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => sendInput(),
    );
    _presence = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _keepPresence(),
    );
  }
  final PongApi api;
  final String handle;
  PongFrame? frame, previousFrame;
  final List<_PongSnapshot> _snapshots = [];
  DateTime receivedAt = DateTime.now();
  String? error, _controlToken;
  int direction = 0, forward = 0, _seq = 0;
  double? targetY;
  StreamSubscription<PongFrame>? _subscription;
  Timer? _heartbeat, _retry, _presence, _sendThrottle;
  bool _disposed = false, _sending = false, _connecting = false;
  bool _sendAgain = false;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  double _paddleCorrection = 0, _depthCorrection = 0;
  Future<void> connect() async {
    if (_disposed || _connecting || frame?.ended == true) return;
    _connecting = true;
    await _subscription?.cancel();
    if (_disposed) return;
    _subscription = api
        .frames(handle)
        .listen(
          (next) {
            final now = DateTime.now();
            final prior = frame;
            final predictedPaddle = frame == null ? null : localPaddleAt(now);
            final predictedDepth = frame == null ? null : localDepthAt(now);
            previousFrame = frame;
            frame = next;
            receivedAt = now;
            _snapshots.add(_PongSnapshot(next, now));
            if (_snapshots.length > 8) _snapshots.removeAt(0);
            final paddles = next.state['paddles'] as List? ?? const [];
            final depths = next.state['depths'] as List? ?? const [];
            if (predictedPaddle != null && next.side < paddles.length) {
              final error =
                  predictedPaddle - (paddles[next.side] as num).toDouble();
              _paddleCorrection = error.abs() <= 36 ? error : 0;
            } else {
              _paddleCorrection = 0;
            }
            if (predictedDepth != null && next.side < depths.length) {
              final error =
                  predictedDepth - (depths[next.side] as num).toDouble();
              _depthCorrection = error.abs() <= 18 ? error : 0;
            } else {
              _depthCorrection = 0;
            }
            error = next.connectionError;
            if (next.controlToken != null) {
              _controlToken = next.controlToken;
              _seq = 0;
            }
            // WHY: The canvas paints from the controller at 60 Hz; HUD state
            // only needs a modest cadence and should not rebuild the whole page.
            if (now.difference(_lastUiUpdate).inMilliseconds >= 150 ||
                next.ended ||
                prior == null ||
                prior.status != next.status ||
                !listEquals(prior.score, next.score) ||
                prior.returns != next.returns) {
              _lastUiUpdate = now;
              notifyListeners();
            }
          },
          onError: (Object e) {
            error = e.toString();
            _reconnect();
          },
          onDone: _reconnect,
        );
    _connecting = false;
  }

  /// Returns a short buffered interpolation sample for remote objects and ball.
  PongRenderSample? renderSampleAt(DateTime now) {
    if (_snapshots.isEmpty) return null;
    final latest = _snapshots.last;
    if (latest.frame.ended || latest.frame.paused || latest.frame.waiting) {
      return PongRenderSample(latest.frame, latest.frame, 1);
    }
    if (_snapshots.length == 1) {
      return PongRenderSample(latest.frame, latest.frame, 1);
    }
    // WHY: A 75 ms render buffer spans ordinary 50 ms server ticks and absorbs
    // modest arrival jitter without extrapolating authoritative ball physics.
    final elapsedAfterLatest = now
        .difference(latest.receivedAt)
        .inMilliseconds
        .clamp(0, 75)
        .toDouble();
    final target = _elapsed(latest.frame) - 75 + elapsedAfterLatest;
    final first = _snapshots.first;
    if (target <= _elapsed(first.frame)) {
      return PongRenderSample(first.frame, first.frame, 1);
    }
    for (var index = 1; index < _snapshots.length; index++) {
      final before = _snapshots[index - 1].frame;
      final after = _snapshots[index].frame;
      final start = _elapsed(before), end = _elapsed(after);
      if (target <= end) {
        if (end <= start) return PongRenderSample(after, after, 1);
        return PongRenderSample(
          before,
          after,
          ((target - start) / (end - start)).clamp(0, 1).toDouble(),
        );
      }
    }
    return PongRenderSample(latest.frame, latest.frame, 1);
  }

  double _elapsed(PongFrame frame) =>
      (frame.state['elapsedMs'] as num? ?? 0).toDouble();

  void _reconnect() {
    if (_disposed || frame?.ended == true) return;
    _controlToken = null;
    error ??= 'Connection interrupted. Reconnecting…';
    notifyListeners();
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 2), connect);
  }

  void move({int? direction, double? targetY, int? forward}) {
    this.direction = direction ?? this.direction;
    this.forward = forward ?? this.forward;
    this.targetY = targetY?.clamp(0, 560).toDouble();
    // WHY: Releasing a key must stop the paddle even inside the drag throttle.
    sendInput(force: direction == 0 && targetY == null);
  }

  /// Display-only prediction. The next server frame remains authoritative.
  double localPaddleAt(DateTime now) {
    final current = frame;
    if (current == null) return 280;
    final paddles = current.state['paddles'] as List? ?? const [];
    if (current.side >= paddles.length) return 280;
    final authoritative = (paddles[current.side] as num).toDouble();
    if (current.ended || current.paused || current.waiting) {
      return authoritative;
    }
    final elapsed =
        now.difference(receivedAt).inMicroseconds.clamp(0, 160000) / 1000000;
    final active = current.effects.length > current.side
        ? pongRows(current.effects[current.side]['active'])
        : const <PongJson>[];
    final speed = 650 * (active.any((e) => e['type'] == 'speed') ? 1.3 : 1.0);
    final heights = current.state['paddleHeights'] as List? ?? const [];
    final half = heights.length > current.side
        ? (heights[current.side] as num).toDouble() / 2
        : 56.0;
    final desired = targetY == null
        ? authoritative + direction * speed * elapsed
        : authoritative +
              (targetY! - authoritative).clamp(
                -speed * elapsed,
                speed * elapsed,
              );
    final correction = _paddleCorrection * (1 - (elapsed / .16).clamp(0, 1));
    return (desired + correction).clamp(half, 560 - half).toDouble();
  }

  /// Draws the local Rush depth immediately, without changing server state.
  double localDepthAt(DateTime now) {
    final current = frame;
    if (current == null) return 0;
    final depths = current.state['depths'] as List? ?? const [];
    if (current.side >= depths.length) return 0;
    final authoritative = (depths[current.side] as num).toDouble();
    if (current.ended || current.paused || current.waiting) {
      return authoritative;
    }
    final elapsed =
        now.difference(receivedAt).inMicroseconds.clamp(0, 160000) / 1000000;
    final rushActive = current.rushReady && forward > 0;
    final desired = authoritative + elapsed * (rushActive ? 170 : -220);
    final correction = _depthCorrection * (1 - (elapsed / .16).clamp(0, 1));
    return (desired + correction).clamp(0, 110).toDouble();
  }

  Future<void> sendInput({bool force = false}) async {
    if (_disposed || _controlToken == null || frame?.ended == true) {
      return;
    }
    if (_sending) {
      _sendAgain = true;
      return;
    }
    final wait = 70 - DateTime.now().difference(_lastSent).inMilliseconds;
    if (!force && wait > 0) {
      _sendThrottle?.cancel();
      _sendThrottle = Timer(
        Duration(milliseconds: wait),
        () => sendInput(force: true),
      );
      return;
    }
    _sending = true;
    _lastSent = DateTime.now();
    try {
      await api.input(
        handle,
        _controlToken!,
        _seq++,
        direction,
        targetY,
        forward: forward,
      );
    } catch (e) {
      if (!_disposed && frame?.ended != true) {
        error = e.toString();
        notifyListeners();
        if (e is PongApiException && e.code == 'PONG_CONTROL_CHANGED') {
          // WHY: Do not steal control back endlessly from another open tab.
          _heartbeat?.cancel();
          _retry?.cancel();
          await _subscription?.cancel();
        }
      }
    } finally {
      _sending = false;
      if (_sendAgain && !_disposed) {
        _sendAgain = false;
        sendInput(force: true);
      }
    }
  }

  Future<void> _keepPresence() async {
    if (_disposed || frame?.ended != true) return;
    try {
      await api.me();
    } catch (e) {
      if (!_disposed) {
        error = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> control(String action) async {
    try {
      await api.control(handle, action);
    } catch (e) {
      if (!_disposed) {
        error = e.toString();
        notifyListeners();
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _heartbeat?.cancel();
    _retry?.cancel();
    _presence?.cancel();
    _sendThrottle?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

class PongRenderSample {
  const PongRenderSample(this.previous, this.current, this.fraction);
  final PongFrame previous, current;
  final double fraction;
}

class _PongSnapshot {
  const _PongSnapshot(this.frame, this.receivedAt);
  final PongFrame frame;
  final DateTime receivedAt;
}
