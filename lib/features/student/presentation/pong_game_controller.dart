/**
 * WHAT: Owns arena connection, reconnect and bounded paddle commands.
 * WHY: Network lifecycle must stay separate from game painting and controls.
 * HOW: Consume server frames, heartbeat inputs and reconnect without claiming wins.
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
  DateTime receivedAt = DateTime.now();
  String? error, _controlToken;
  int direction = 0, _seq = 0;
  double? targetY;
  StreamSubscription<PongFrame>? _subscription;
  Timer? _heartbeat, _retry, _presence;
  bool _disposed = false, _sending = false, _connecting = false;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> connect() async {
    if (_disposed || _connecting || frame?.ended == true) return;
    _connecting = true;
    await _subscription?.cancel();
    if (_disposed) return;
    _subscription = api
        .frames(handle)
        .listen(
          (next) {
            previousFrame = frame;
            frame = next;
            receivedAt = DateTime.now();
            error = next.connectionError;
            if (next.controlToken != null) {
              _controlToken = next.controlToken;
              _seq = 0;
            }
            notifyListeners();
          },
          onError: (Object e) {
            error = e.toString();
            _reconnect();
          },
          onDone: _reconnect,
        );
    _connecting = false;
  }

  void _reconnect() {
    if (_disposed || frame?.ended == true) return;
    _controlToken = null;
    error ??= 'Connection interrupted. Reconnecting…';
    notifyListeners();
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 2), connect);
  }

  void move({int? direction, double? targetY}) {
    this.direction = direction ?? 0;
    this.targetY = targetY?.clamp(0, 560).toDouble();
    // WHY: Releasing a key must stop the paddle even inside the drag throttle.
    sendInput(force: direction == 0 && targetY == null);
  }

  Future<void> sendInput({bool force = false}) async {
    if (_disposed ||
        _sending ||
        _controlToken == null ||
        frame?.ended == true ||
        (!force && DateTime.now().difference(_lastSent).inMilliseconds < 70)) {
      return;
    }
    _sending = true;
    _lastSent = DateTime.now();
    try {
      await api.input(handle, _controlToken!, _seq++, direction, targetY);
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
    _subscription?.cancel();
    super.dispose();
  }
}
