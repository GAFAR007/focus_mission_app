/**
 * WHAT: Owns arena connection, reconnect and bounded paddle commands.
 * WHY: Network lifecycle must stay separate from game painting and controls.
 * HOW: Consume server frames, predict only the local paddle for display, throttle
 * input state, and reconcile against the authoritative simulation.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../../core/utils/pong_api.dart';
import '../../../shared/models/pong_models.dart';

class PongGameController extends ChangeNotifier {
  PongGameController(this.api, this.handle, {DateTime Function()? clock}) {
    final watch = Stopwatch()..start();
    final epoch = DateTime.now();
    now = clock ?? () => epoch.add(watch.elapsed);
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
  late final DateTime Function() now;
  final PongMotionDiagnostics diagnostics = PongMotionDiagnostics();
  static const interpolationDelayMs = 100.0;
  static const staleInputMs = 200;
  static const correctionWindowMs = 140.0;
  DateTime? _predictionAt, _renderAt, _arrivalAt;
  double _localY = 280, _localDepth = 0, _remainingY = 0, _remainingDepth = 0;
  double _renderTime = 0;
  bool _connectionLost = false;
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
  Future<void> connect() async {
    if (_disposed || _connecting || frame?.ended == true) return;
    _connecting = true;
    await _subscription?.cancel();
    if (_disposed) return;
    _subscription = api
        .frames(handle)
        .listen(
          (next) {
            final instant = now();
            final prior = frame;
            final newController =
                next.controlToken != null && next.controlToken != _controlToken;
            final boundary =
                prior == null ||
                _connectionLost ||
                newController ||
                _discontinuity(prior, next);
            if (prior != null &&
                !newController &&
                !_connectionLost &&
                _elapsed(next) < _elapsed(prior)) {
              diagnostics.lateSnapshots++;
              return;
            }
            diagnostics.arrival(
              _arrivalAt == null
                  ? null
                  : instant.difference(_arrivalAt!).inMicroseconds / 1000,
            );
            _arrivalAt = instant;
            _advanceLocal(instant);
            previousFrame = prior;
            frame = next;
            receivedAt = instant;
            _connectionLost = false;
            final authoritative = (next.state['paddles'][next.side] as num)
                .toDouble();
            final depth =
                ((next.state['depths'] as List? ?? [0, 0])[next.side] as num)
                    .toDouble();
            diagnostics.authoritative = authoritative;
            diagnostics.predicted = _localY;
            diagnostics.correction = authoritative - _localY;
            if (boundary || (authoritative - _localY).abs() > 140) {
              _localY = authoritative;
              _localDepth = depth;
              _remainingY = 0;
              _remainingDepth = 0;
            } else {
              // Preserve the displayed position at packet receipt. Apply only
              // the error over subsequent render time, never retroactive input.
              _remainingY = authoritative - _localY;
              _remainingDepth = depth - _localDepth;
            }
            _predictionAt = instant;
            if (boundary) {
              _snapshots.clear();
              _renderTime = _elapsed(next) - interpolationDelayMs;
              _renderAt = instant;
              diagnostics.resets++;
            }
            if (_snapshots.isEmpty ||
                _elapsed(next) > _elapsed(_snapshots.last.frame)) {
              _snapshots.add(_PongSnapshot(next, instant));
              if (_snapshots.length > 32) _snapshots.removeAt(0);
            } else {
              diagnostics.duplicateSnapshots++;
              _snapshots[_snapshots.length - 1] = _PongSnapshot(next, instant);
            }
            error = next.connectionError;
            if (next.controlToken != null) {
              if (newController) _seq = 0;
              _controlToken = next.controlToken;
            }
            // WHY: The canvas paints from the controller at 60 Hz; HUD state
            // only needs a modest cadence and should not rebuild the whole page.
            if (instant.difference(_lastUiUpdate).inMilliseconds >= 150 ||
                boundary ||
                next.ended ||
                prior.status != next.status ||
                !listEquals(prior.score, next.score) ||
                prior.returns != next.returns) {
              _lastUiUpdate = instant;
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
    if (_connectionLost ||
        latest.frame.ended ||
        latest.frame.paused ||
        latest.frame.waiting) {
      return PongRenderSample(latest.frame, latest.frame, 1);
    }
    if (_snapshots.length == 1) {
      return PongRenderSample(latest.frame, latest.frame, 1);
    }
    // A persistent cursor advances by render time, not packet arrival time.
    // Network bursts cannot rewind the ball. A small clock slew absorbs drift;
    // starvation holds the last known position and never invents a collision.
    final dt = _renderAt == null
        ? 0.0
        : now.difference(_renderAt!).inMicroseconds.clamp(0, 200000) / 1000;
    _renderAt = now;
    final desired =
        _elapsed(latest.frame) -
        interpolationDelayMs +
        now.difference(latest.receivedAt).inMicroseconds.clamp(0, 200000) /
            1000;
    final rate = 1 + ((desired - _renderTime) / 1000).clamp(-.05, .05);
    _renderTime = math.min(_elapsed(latest.frame), _renderTime + dt * rate);
    final target = _renderTime;
    diagnostics.bufferDepthMs = _elapsed(latest.frame) - target;
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
    _advanceLocal(now());
    _connectionLost = true;
    _snapshots.clear();
    _controlToken = null;
    error ??= 'Connection interrupted. Reconnecting…';
    notifyListeners();
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 2), connect);
  }

  void move({int? direction, double? targetY, int? forward}) {
    _advanceLocal(now());
    this.direction = direction ?? this.direction;
    this.forward = forward ?? this.forward;
    this.targetY = targetY?.clamp(0, 560).toDouble();
    // WHY: Releasing a key must stop the paddle even inside the drag throttle.
    sendInput(force: direction == 0 && targetY == null);
  }

  bool _discontinuity(PongFrame a, PongFrame b) {
    final shield = pongRows(b.state['events']).any(
      (e) =>
          e['type'] == 'shield' &&
          !pongRows(a.state['events']).any((old) => old['id'] == e['id']),
    );
    return a.status != b.status ||
        a.paused != b.paused ||
        a.waiting != b.waiting ||
        a.level != b.level ||
        a.state['arena'] != b.state['arena'] ||
        a.state['phase'] != b.state['phase'] ||
        !listEquals(a.score, b.score) ||
        shield ||
        (_elapsed(b) - _elapsed(a)).abs() > 400;
  }

  /// Both axes integrate once per instant. Input changes checkpoint the old
  /// trajectory before replacing it, so release/reversal cannot move backwards.
  void _advanceLocal(DateTime instant) {
    final current = frame;
    if (current == null) return;
    final prior = _predictionAt ?? instant;
    _predictionAt = instant;
    if (_connectionLost || current.ended || current.paused || current.waiting) {
      return;
    }
    final cutoff = receivedAt.add(const Duration(milliseconds: staleInputMs));
    final end = instant.isAfter(cutoff) ? cutoff : instant;
    final dt = end.difference(prior).inMicroseconds.clamp(0, 200000) / 1000000;
    final active = current.effects.length > current.side
        ? pongRows(current.effects[current.side]['active'])
        : const <PongJson>[];
    final speed = 650 * (active.any((e) => e['type'] == 'speed') ? 1.3 : 1.0);
    final heights = current.state['paddleHeights'] as List? ?? const [];
    final half = heights.length > current.side
        ? (heights[current.side] as num).toDouble() / 2
        : 56.0;
    final advance = targetY == null
        ? direction * speed * dt
        : (targetY! - _localY).clamp(-speed * dt, speed * dt);
    final weight = 1 - math.exp(-dt * 1000 / correctionWindowMs);
    final correctionY = _remainingY * weight,
        correctionDepth = _remainingDepth * weight;
    _remainingY -= correctionY;
    _remainingDepth -= correctionDepth;
    _localY = (_localY + advance + correctionY)
        .clamp(half, 560 - half)
        .toDouble();
    _localDepth =
        (_localDepth +
                dt * (current.rushReady && forward > 0 ? 170 : -220) +
                correctionDepth)
            .clamp(0, 110)
            .toDouble();
  }

  double localPaddleAt(DateTime instant) {
    _advanceLocal(instant);
    return _localY;
  }

  double localDepthAt(DateTime instant) {
    _advanceLocal(instant);
    return _localDepth;
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

/// Development measurements contain timings and distances only, no identities.
class PongMotionDiagnostics {
  int snapshots = 0, lateSnapshots = 0, duplicateSnapshots = 0, resets = 0;
  double totalIntervalMs = 0, worstIntervalMs = 0, bufferDepthMs = 0;
  double predicted = 0, authoritative = 0, correction = 0, worstFrameMs = 0;
  DateTime? _paintAt;
  int paints = 0, delayedPaints = 0, arrivalGaps = 0;
  double totalFrameMs = 0;
  void arrival(double? interval) {
    snapshots++;
    if (interval == null) return;
    totalIntervalMs += interval;
    if (interval > 100) arrivalGaps++;
    worstIntervalMs = math.max(worstIntervalMs, interval);
  }

  void paint(DateTime instant) {
    paints++;
    if (_paintAt != null) {
      final interval = instant.difference(_paintAt!).inMicroseconds / 1000;
      totalFrameMs += interval;
      if (interval > 25) delayedPaints++;
      worstFrameMs = math.max(
        worstFrameMs,
        instant.difference(_paintAt!).inMicroseconds / 1000,
      );
    }
    _paintAt = instant;
  }

  Map<String, num> get summary => {
    'snapshots': snapshots,
    'meanArrivalMs': totalIntervalMs / math.max(1, snapshots - 1),
    'worstArrivalMs': worstIntervalMs,
    'worstFrameMs': worstFrameMs,
    'paints': paints,
    'meanFrameMs': totalFrameMs / math.max(1, paints - 1),
    'delayedPaintsOver25ms': delayedPaints,
    'arrivalGapsOver100ms': arrivalGaps,
    'predicted': predicted,
    'authoritative': authoritative,
    'correction': correction,
    'bufferMs': bufferDepthMs,
    'late': lateSnapshots,
    'duplicates': duplicateSnapshots,
    'resets': resets,
  };
}
