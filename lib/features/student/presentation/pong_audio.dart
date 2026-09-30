/**
 * WHAT: Optional quiet sound cues for authoritative Pong events.
 * WHY: Hits and boosts benefit from feedback without making sound mandatory.
 * HOW: Reuse the installed audio player with short original local tones.
 * WHO: The student Pong arena owns event playback and mute state.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class PongAudio {
  AudioPlayer? _player;
  bool muted = true;
  int _lastEvent = 0;
  DateTime _lastPlayed = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> events(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;
    final event = events.last;
    final id = event['id'] as int;
    if (id <= _lastEvent) return;
    _lastEvent = id;
    if (muted || DateTime.now().difference(_lastPlayed).inMilliseconds < 65) {
      return;
    }
    const sounds = {'hit', 'wall', 'pickup', 'shield', 'strongHit', 'point'};
    if (!sounds.contains(event['type'])) return;
    _lastPlayed = DateTime.now();
    try {
      _player ??= AudioPlayer();
      await _player!.play(
        AssetSource('sounds/pong/${event['type']}.wav'),
        volume: .18,
      );
    } catch (_) {
      // Sound is optional; browser autoplay restrictions must never stop play.
      muted = true;
      debugPrint('[pong] Audio unavailable; game continues muted.');
    }
  }

  Future<void> dispose() async => _player?.dispose();
}
