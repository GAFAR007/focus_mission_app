# Focus Mission Pong music provenance

Verified 2026-10-03 against the original OpenGameArt track pages and their CC0
licence links. The macOS download-origin metadata identifies the original file
URLs below; SHA-256 fingerprints identify the exact downloaded inputs. No
additional tracks were downloaded. Original downloads remain untouched.

All three selected works are CC0 1.0, which permits redistribution in a
commercial/educational application and modification/transcoding/loop processing.
Licence: https://creativecommons.org/publicdomain/zero/1.0/
Legal text: https://creativecommons.org/publicdomain/zero/1.0/legalcode

| Title | Creator | Original source | Original downloaded filename | Production asset |
|---|---|---|---|---|
| City Loop | wipics | https://opengameart.org/content/city-loop-0 | `city-loop_0.mp3` | `assets/music/pong/city.mp3` |
| Empacotatron | Fupi | https://opengameart.org/content/empacotatron | `empacotatron_loop (1).ogg` | `assets/music/pong/empacotatron.mp3` |
| Bouncer | Of Far Different Nature | https://opengameart.org/content/bouncer-0 | `Of Far Different Nature - Bouncer (CC0)_1.mp3` | `assets/music/pong/bouncer.mp3` |

Bouncer is the original CC0 recording, not the separate Bouncer v2 arrangement.

## Download audit

All sources are stereo, 44,100 Hz.

| Download | Duration (s) | Bytes | SHA-256 |
|---|---:|---:|---|
| City MP3 | 56.424490 | 1,358,284 | `9349982fb8e365167bc5c89f2ac50d3b5376b9f627d506ba30a9b26c8230597e` |
| Empacotatron Ogg Vorbis | 80.000000 | 1,819,852 | `da95a6c87759d0b82f6153970a19c345a30241f2705b798eaca93b0a40e209e8` |
| Bouncer MP3 | 93.759615 | 3,755,320 | `453f703d5b3fdb6045078c446ff82bad97b19eb6b660ed2da76b64dd971bfcba` |

Original files referenced by their source pages/download metadata:

- https://opengameart.org/sites/default/files/city-loop_0.mp3
- https://opengameart.org/sites/default/files/empacotatron_loop.ogg
- https://opengameart.org/sites/default/files/Of%20Far%20Different%20Nature%20-%20Bouncer%20%28CC0%29_1.mp3

## Production modifications and use

Modified: **yes, all three**. FFmpeg transcodes each to 160 kbit/s stereo MP3,
removes source metadata/embedded artwork, and keeps the original musical duration.
City is attenuated 6 dB and Bouncer 10 dB before encoding to bring their average
levels closer to Empacotatron and provide decoded-peak headroom. Empacotatron uses
no additional gain adjustment. No separated stems, new composition or dynamic
rally-intensity system is claimed: this task selects music by route/mode.

Reproduction command pattern (replace SOURCE and OUTPUT with the table entries):

```sh
ffmpeg -i SOURCE -vn -map_metadata -1 -af volume=GAIN -c:a libmp3lame -b:a 160k OUTPUT
```

Use `GAIN=-6dB` for City, `GAIN=-10dB` for Bouncer, and omit `-af` for Empacotatron.
Production assets total approximately 4.61 MB. No uncompressed masters are bundled.

- City: home, levels and student lobby; 3-second overlap at the ending.
- Empacotatron: computer levels 1–10 and Classic; 120-ms loop overlap.
- Bouncer: levels 11–15 and Power Battle; 2-second ending overlap.
- Route/mode crossfade: 650 ms. Point events do not restart the music.
- Two reused music channels; maximum eight reusable effect channels.
- Music starts muted, respects a Pong user gesture, and uses device preferences.
- Assets load from the app origin, never from OpenGameArt during gameplay.

Decoder, duration, peak, asset inclusion and audio-lifecycle tests are technical
checks, not proof of listening quality. Final listening acceptance of the mix and
loop seams must be recorded separately in the Pong QA report.
