/**
 * WHAT: Pong-only music crossfades, pooled effects and device audio settings.
 * WHY: Rapid hits must overlap and route changes must not duplicate soundtracks.
 * HOW: Two reusable music channels and preloaded per-effect channels use the
 * existing audio stack. One owner passes this session through its child routes.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin player boundary permits lifecycle/race tests without a platform decoder.
class PongAudioChannel {
  final AudioPlayer _player = AudioPlayer();
  String? _prepared;
  Future<void> prepare(String path) async {
    if (_prepared == path) {
      await _player.seek(Duration.zero);
      return;
    }
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSource(AssetSource(path));
    _prepared = path;
  }

  Future<void> start() => _player.resume();
  Future<void> pause() => _player.pause();
  Future<void> rewind() => _player.seek(Duration.zero);
  Future<void> volume(double value) => _player.setVolume(value);
  Future<Duration?> position() => _player.getCurrentPosition();
  Future<void> dispose() => _player.dispose();
}

enum PongTrack {
  city('city.mp3', 56.424, 3),
  empacotatron('empacotatron.mp3', 80, .12),
  bouncer('bouncer.mp3', 93.759, 2);

  const PongTrack(this.file, this.seconds, this.overlap);
  final String file;
  final double seconds, overlap;
  static PongTrack match({required bool power, required int level}) =>
      power || level >= 11 ? bouncer : empacotatron;
}

class PongAudio extends ChangeNotifier {
  PongAudio({PongAudioChannel Function()? createChannel})
    : _createChannel = createChannel ?? PongAudioChannel.new;
  final PongAudioChannel Function() _createChannel;
  bool muted = true, musicEnabled = true, sfxEnabled = true;
  double musicVolume = .10;
  bool _disposed = false,
      _background = false,
      _suspended = false,
      _busyTick = false;
  bool _activated = false;
  int _lastEvent = 0, _revision = 0, _active = 0;
  String? _match;
  PongTrack? _wanted, _playing;
  final List<PongAudioChannel> _music = [];
  final Map<String, List<PongAudioChannel>> _effects = {};
  final Map<String, int> _effectCursor = {};
  final Map<String, DateTime> _effectAt = {};
  Future<void> _queue = Future.value();
  Timer? _timer;
  double _gain = 0;
  static const _volumes = {
    'hit': .32,
    'wall': .22,
    'pickup': .34,
    'shield': .38,
    'strongHit': .38,
    'point': .40,
  };

  Future<void> loadPreferences() async {
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed || revision != _revision) return;
      muted = prefs.getBool('pong.muted') ?? true;
      musicEnabled = prefs.getBool('pong.music') ?? true;
      sfxEnabled = prefs.getBool('pong.sfx') ?? true;
      musicVolume = (prefs.getDouble('pong.musicVolume') ?? .10).clamp(0, .3);
      notifyListeners();
    } catch (_) {
      /* Device storage is optional; quiet defaults remain. */
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pong.muted', muted);
      await prefs.setBool('pong.music', musicEnabled);
      await prefs.setBool('pong.sfx', sfxEnabled);
      await prefs.setDouble('pong.musicVolume', musicVolume);
    } catch (_) {
      /* Preferences never gate play. */
    }
  }

  // Invoked by a Pong button/pointer/keyboard gesture, never by a server event.
  void activate() {
    if (_activated || _disposed) return;
    _activated = true;
    _sync();
  }

  void setMuted(bool value) {
    muted = value;
    _changed();
  }

  void setMusicEnabled(bool value) {
    musicEnabled = value;
    _changed();
  }

  void setSfxEnabled(bool value) {
    sfxEnabled = value;
    _changed();
  }

  void setMusicVolume(double value) {
    musicVolume = value.clamp(0, .3);
    _changed();
  }

  void _changed() {
    _revision++;
    notifyListeners();
    unawaited(_save());
    _activated = true;
    _sync();
  }

  void select(PongTrack? track, {String? match}) {
    if (_match != match) {
      _match = match;
      _lastEvent = 0;
    }
    if (_wanted == track) return;
    _wanted = track;
    _sync();
  }

  void background(bool value) {
    if (_background == value || _disposed) return;
    _background = value;
    _sync();
  }

  // Game pause/reconnect is independent of application visibility. An incoming
  // network frame must never resume audio while the browser tab is hidden.
  void suspend(bool value) {
    if (_suspended == value || _disposed) return;
    _suspended = value;
    _sync();
  }

  bool get _audible =>
      !_disposed && _activated && !muted && !_background && !_suspended;
  void _enqueue(Future<void> Function() action) {
    _queue = _queue
        .then((_) async {
          if (!_disposed) await action();
        })
        .catchError((Object e) {
          // Browser activation/decoder errors must not become game errors.
          debugPrint('[pong] Optional audio unavailable (${e.runtimeType}).');
        });
  }

  void _sync() => _enqueue(() async {
    if (!_audible) {
      _timer?.cancel();
      for (final channel in [..._music, ..._effects.values.expand((v) => v)]) {
        await channel.pause();
      }
      return;
    }
    if (sfxEnabled && _effects.isEmpty) {
      for (final effect in _volumes.keys) {
        final pool = <PongAudioChannel>[];
        _effects[effect] = pool;
        for (
          var i = 0;
          i < (effect == 'hit' || effect == 'wall' ? 2 : 1);
          i++
        ) {
          if (_disposed) return;
          final channel = _createChannel();
          pool.add(channel);
          try {
            await channel
                .prepare('sounds/pong/$effect.wav')
                .timeout(const Duration(seconds: 2));
            await channel.volume(_volumes[effect]!);
          } catch (_) {
            /* A missing effect does not disable the music bus. */
          }
        }
      }
    }
    if (!_audible) return;
    if (!sfxEnabled) {
      for (final channel in _effects.values.expand((v) => v)) {
        await channel.pause();
      }
    }
    if (!musicEnabled || _wanted == null) {
      await _fadeOut();
      return;
    }
    if (_music.isEmpty) _music.addAll([_createChannel(), _createChannel()]);
    if (_playing != _wanted) {
      await _crossfade(_wanted!, const Duration(milliseconds: 650));
    } else {
      _gain = musicVolume;
      await _music[_active].volume(musicVolume);
      await _music[_active].start();
    }
    if (!_audible || !musicEnabled) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  });

  Future<void> _crossfade(PongTrack track, Duration duration) async {
    final next = 1 - _active, old = _active;
    await _music[next]
        .prepare('music/pong/${track.file}')
        .timeout(const Duration(seconds: 4));
    if (!_audible || !musicEnabled) return;
    await _music[next].volume(0);
    await _music[next].start();
    final oldGain = _gain;
    final watch = Stopwatch()..start();
    while (!_disposed && watch.elapsed < duration) {
      if (!_audible || !musicEnabled) {
        await _music[next].pause();
        await _music[old].pause();
        return;
      }
      final progress = (watch.elapsedMicroseconds / duration.inMicroseconds)
          .clamp(0.0, 1.0);
      await _music[next].volume(musicVolume * progress);
      await _music[old].volume(oldGain * (1 - progress));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    await _music[old].volume(0);
    await _music[old].pause();
    await _music[next].volume(musicVolume);
    _gain = musicVolume;
    _active = next;
    _playing = track;
    // Warm the silent standby channel now, not in the final 120 ms of a loop.
    // This also replaces an older route's source while the new track plays.
    try {
      await _music[old]
          .prepare('music/pong/${track.file}')
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Keep the active soundtrack; the next transition may retry this decoder.
    }
  }

  Future<void> _fadeOut() async {
    _timer?.cancel();
    if (_music.isEmpty) return;
    final gain = _gain;
    for (var step = 1; step <= 8 && !_disposed; step++) {
      await _music[_active].volume(gain * (1 - step / 8));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    for (final channel in _music) {
      await channel.pause();
    }
    _gain = 0;
    _playing = null;
  }

  void _tick() {
    if (_busyTick || !_audible || !musicEnabled || _playing == null) return;
    _busyTick = true;
    _enqueue(() async {
      try {
        final track = _playing;
        if (track == null || !_audible) return;
        final position = await _music[_active].position();
        if (position != null &&
            position.inMilliseconds >= (track.seconds - track.overlap) * 1000) {
          await _crossfade(
            track,
            Duration(milliseconds: (track.overlap * 1000).round()),
          );
        }
      } finally {
        _busyTick = false;
      }
    });
  }

  Future<void> events(List<Map<String, dynamic>> events) async {
    for (final event in events) {
      final id = event['id'] as int;
      if (id <= _lastEvent) continue;
      _lastEvent = id;
      final type = event['type'] as String;
      final pool = _effects[type];
      if (!_audible || !sfxEnabled || pool == null || pool.isEmpty) continue;
      final now = DateTime.now();
      if (now.difference(_effectAt[type] ?? DateTime(1970)).inMilliseconds <
          25) {
        continue;
      }
      _effectAt[type] = now;
      final cursor = _effectCursor[type] ?? 0;
      _effectCursor[type] = cursor + 1;
      // Different effects never steal one another's player. Hits alternate.
      final channel = pool[cursor % pool.length];
      unawaited(_effect(channel));
    }
  }

  Future<void> _effect(PongAudioChannel channel) async {
    try {
      await channel.rewind();
      if (_audible && sfxEnabled) await channel.start();
    } catch (_) {
      /* Optional feedback; physics is independent. */
    }
  }

  @visibleForTesting
  Future<void> get settled => _queue;

  Future<void>? _closing;
  Future<void> close() {
    dispose();
    return _closing ?? Future.value();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    super.dispose();
    _closing = _queue.then((_) async {
      for (final channel in [..._music, ..._effects.values.expand((v) => v)]) {
        try {
          await channel.dispose();
        } catch (_) {
          /* Already released. */
        }
      }
      _music.clear();
      _effects.clear();
    });
  }
}
