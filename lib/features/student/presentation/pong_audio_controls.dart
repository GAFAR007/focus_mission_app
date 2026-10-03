/**
 * WHAT: Compact Pong master mute and independent music/effect preferences.
 * WHY: Learners can silence the entire game without losing their preferred mix.
 * HOW: Listen only to settings changes; keep controls out of the paint loop.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'package:flutter/material.dart';
import 'pong_audio.dart';

class PongAudioControls extends StatelessWidget {
  const PongAudioControls({super.key, required this.audio});
  final PongAudio audio;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: audio,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: audio.muted ? 'Unmute game' : 'Mute game',
          onPressed: () => audio.setMuted(!audio.muted),
          icon: Icon(
            audio.muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
          ),
        ),
        IconButton(
          tooltip: 'Audio settings',
          icon: const Icon(Icons.tune),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => ListenableBuilder(
              listenable: audio,
              builder: (context, _) => AlertDialog(
                title: const Text('Pong audio'),
                content: SizedBox(
                  width: 340,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text('Mute all'),
                        value: audio.muted,
                        onChanged: audio.setMuted,
                      ),
                      SwitchListTile(
                        title: const Text('Music'),
                        value: audio.musicEnabled,
                        onChanged: audio.setMusicEnabled,
                      ),
                      SwitchListTile(
                        title: const Text('Sound FX'),
                        value: audio.sfxEnabled,
                        onChanged: audio.setSfxEnabled,
                      ),
                      const Text('Music volume'),
                      Slider(
                        value: audio.musicVolume,
                        max: .3,
                        semanticFormatterCallback: (v) =>
                            '${(v / .3 * 100).round()} percent',
                        onChanged: audio.setMusicVolume,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
