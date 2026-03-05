/**
 * WHAT:
 * Web celebration-sound helpers for mission answer fireworks.
 * WHY:
 * Some web sessions fail plugin-channel audio init, so the celebration cue
 * must still play through browser-native audio.
 * HOW:
 * Use the browser audio element with the Flutter web asset URL and replay
 * from the start for each correct answer.
 */
// ignore_for_file: avoid_web_libraries_in_flutter, dangling_library_doc_comments, deprecated_member_use, slash_for_doc_comments

import 'dart:html' as html;

const String _webSoundUrl = 'assets/sounds/hurray.wav';

Future<void> warmupHurraySound() async {
  final audio = html.AudioElement(_webSoundUrl)
    ..preload = 'auto'
    ..volume = 0.9;
  audio.load();
}

Future<void> playHurraySound() async {
  final audio = html.AudioElement(_webSoundUrl)
    ..preload = 'auto'
    ..volume = 0.9
    ..currentTime = 0;

  try {
    await audio.play();
  } catch (_) {
    // WHY: Playback can still be blocked by browser gesture/media policies.
  }
}
