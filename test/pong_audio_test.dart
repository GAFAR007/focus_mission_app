/**
 * WHAT: Exercises Pong audio ownership, independent buses and route changes.
 * WHY: Playback failures or rapid input must never leak players or gate a match.
 * HOW: Fake the platform channel while running the real serial fade lifecycle.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_mission_app/features/student/presentation/pong_audio.dart';

class Channel implements PongAudioChannel {
  String? path;
  int starts = 0, pauses = 0, closes = 0, prepares = 0;
  double gain = 0;
  Duration at = Duration.zero;
  bool fail = false;
  @override
  Future<void> prepare(String value) async {
    prepares++;
    if (fail) throw StateError('decoder unavailable');
    path = value;
    at = Duration.zero;
  }

  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> rewind() async {
    at = Duration.zero;
  }

  @override
  Future<void> volume(double value) async {
    gain = value;
  }

  @override
  Future<Duration?> position() async => at;
  @override
  Future<void> dispose() async {
    closes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Channel> channels;
  late PongAudio audio;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    channels = [];
    audio = PongAudio(
      createChannel: () {
        final c = Channel();
        channels.add(c);
        return c;
      },
    );
  });
  tearDown(() async => audio.close());
  test(
    'quiet first run requires a gesture and keeps music separate from SFX',
    () async {
      await audio.loadPreferences();
      audio.select(PongTrack.city);
      await audio.settled;
      expect(audio.muted, true);
      expect(channels, isEmpty);
      audio.activate();
      await audio.settled;
      expect(channels, isEmpty);
      audio.setMusicEnabled(false);
      audio.setMuted(false);
      await audio.settled;
      expect(channels.length, 8);
      expect(channels.every((c) => c.starts == 0), true);
      await audio.events([
        {'id': 1, 'type': 'hit'},
        {'id': 2, 'type': 'wall'},
        {'id': 3, 'type': 'pickup'},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(channels.where((c) => c.starts == 1).length, 3);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await audio.events([
        {'id': 4, 'type': 'hit'},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        channels
            .where((c) => c.path?.endsWith('hit.wav') == true)
            .map((c) => c.starts),
        [1, 1],
      );
      audio.setSfxEnabled(false);
      audio.setMusicEnabled(true);
      await audio.settled;
      expect(
        channels.any(
          (c) => c.path?.endsWith('city.mp3') == true && c.starts > 0,
        ),
        true,
      );
      final hits = channels
          .where((c) => c.path?.endsWith('hit.wav') == true)
          .fold(0, (n, c) => n + c.starts);
      await audio.events([
        {'id': 5, 'type': 'hit'},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        channels
            .where((c) => c.path?.endsWith('hit.wav') == true)
            .fold(0, (n, c) => n + c.starts),
        hits,
      );
    },
  );
  test(
    'same-match points and repeated gestures do not restart music',
    () async {
      audio.select(PongTrack.empacotatron, match: 'one');
      audio.setMuted(false);
      await audio.settled;
      final music = channels
          .where((c) => c.path?.endsWith('.mp3') == true && c.gain > 0)
          .single;
      final starts = music.starts, prepares = music.prepares;
      for (var i = 0; i < 20; i++) {
        audio.activate();
        audio.background(false);
        audio.select(PongTrack.empacotatron, match: 'one');
      }
      await audio.events([
        {'id': 1, 'type': 'point'},
      ]);
      await audio.settled;
      expect(music.starts, starts);
      expect(music.prepares, prepares);
      audio.select(PongTrack.bouncer, match: 'two');
      await audio.settled;
      expect(music.gain, 0);
      expect(music.pauses, greaterThan(0));
      expect(
        channels.any(
          (c) =>
              c.path?.endsWith('bouncer.mp3') == true &&
              c.gain == audio.musicVolume,
        ),
        true,
      );
      expect(channels.length, 10);
    },
  );
  test(
    'hidden app stays silent when an incoming frame clears game pause',
    () async {
      audio.select(PongTrack.city);
      audio.setMuted(false);
      await audio.settled;
      audio.background(true);
      audio.suspend(true);
      await audio.settled;
      final starts = channels.fold(0, (n, c) => n + c.starts);
      audio.suspend(false);
      await audio.settled;
      expect(channels.fold(0, (n, c) => n + c.starts), starts);
      audio.background(false);
      await audio.settled;
      expect(channels.fold(0, (n, c) => n + c.starts), greaterThan(starts));
      audio.select(null);
      await audio.settled;
      expect(
        channels
            .where((c) => c.path?.endsWith('.mp3') == true)
            .every((c) => c.gain == 0),
        true,
      );
    },
  );
  test('loop seam uses the second reusable channel', () async {
    audio.select(PongTrack.empacotatron);
    audio.setMuted(false);
    await audio.settled;
    final first = channels
        .where((c) => c.path?.endsWith('.mp3') == true && c.gain > 0)
        .single;
    final standby = channels
        .where((c) => c.path?.endsWith('.mp3') == true && c != first)
        .single;
    expect(standby.starts, 0);
    first.at = const Duration(milliseconds: 79900);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await audio.settled;
    expect(
      channels
          .where((c) => c.path?.endsWith('empacotatron.mp3') == true)
          .length,
      2,
    );
    expect(first.gain, 0);
    expect(standby.starts, 1);
    expect(channels.length, 10);
  });
  test(
    'mute during fade cancels sound and cleanup disposes every player once',
    () async {
      audio.select(PongTrack.bouncer);
      audio.setMuted(false);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      audio.setMuted(true);
      await audio.settled;
      expect(channels.every((c) => c.pauses > 0), true);
      await audio.close();
      await audio.close();
      expect(channels.every((c) => c.closes == 1), true);
    },
  );
  test(
    'device preferences persist independently and decoding failure is optional',
    () async {
      audio.setMusicEnabled(false);
      audio.setSfxEnabled(false);
      audio.setMusicVolume(.17);
      audio.setMuted(false);
      await audio.settled;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final restored = PongAudio();
      await restored.loadPreferences();
      expect(restored.muted, false);
      expect(restored.musicEnabled, false);
      expect(restored.sfxEnabled, false);
      expect(restored.musicVolume, .17);
      await restored.close();
      final failed = PongAudio(createChannel: () => Channel()..fail = true);
      failed.select(PongTrack.city);
      failed.setMuted(false);
      await failed.settled;
      await failed.close();
    },
  );
  test('track policy preserves Classic and all 15 computer levels', () {
    for (var level = 1; level <= 15; level++) {
      expect(
        PongTrack.match(power: false, level: level),
        level >= 11 ? PongTrack.bouncer : PongTrack.empacotatron,
      );
    }
    expect(PongTrack.match(power: true, level: 1), PongTrack.bouncer);
  });
}
