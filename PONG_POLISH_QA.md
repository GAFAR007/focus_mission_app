# Focus Mission Cup Pong — 3 October 2026

## Scope and source identity

Target frontend: `/Users/gafar/Developer/myPlayGround/App/focus_mission_app`.
Target backend: sibling `focus_mission_backend`. The supplied ZIP source trees
match these checkouts. Baselines: frontend `f414892`, backend `a2b6f0d`, version
**2.3.1** at implementation time. The checks below record the original local
implementation and acceptance. The subsequent v2.4.0 release included teacher
Paste Text only; the owner then requested the missing Pong update. The paired
Release Agent now handles its release from that baseline. See `release/history.json`
for the generated version, source digests and release validation.

MovieAnimator and AI Pong Championship were not modified. AI Pong's court/HUD
craft was inspected as reference; its identities, accounts, game engine, powers
and product features were not imported. Backend source, API contracts, authority,
permissions, school scoping and academic systems are unchanged.

Pre-existing work retained: the frontend mentor overview edits, `lib.zip`,
`devtools_options.yaml`, backend `src.zip` and the Abdul conversion utility.

## Jitter investigation and correction

The original predictor recomputed the paddle using **the newest input applied
retroactively to time since the previous packet**. An 80-ms interval at 650
world units/second produced a **52-unit instant jump on press**, then **-52 on
release**, without elapsed render time. A second path sent an extra position
step from stale authoritative coordinates after releasing an on-screen button.
The old interpolation clock also recomputed its target from each packet arrival,
allowing network timing to alter the visual trajectory.

Changes:

- A monotonic elapsed clock integrates the old input before changing direction or
  touch target. Press/release/reversal at the same instant now moves **0 units**.
- Local positions remain bounded; small server errors ease over a 140-ms window.
  Errors above 140 world units reset to authority. Prediction stops after 200 ms
  without fresh state. No predicted ball collision or score is invented.
- A persistent render cursor interpolates a bounded timestamped snapshot buffer
  approximately 100 ms behind authority. Clock slew is limited to 5%; buffer
  starvation holds the newest known state rather than extrapolating collisions.
- Score, serve/phase, shield, pause, reconnect, arena and match boundaries clear
  interpolation. Older packets are ignored, including stale ready/serve packets.
- Pointer release sends stop without the Material tap handler adding a stale step.
- Diagnostic counters track packet intervals, late/duplicate packets, buffer
  depth, displayed/authoritative positions, correction distance and paint cadence.
  Production diagnostics are off unless built with `PONG_DIAGNOSTICS=true`.

The deterministic irregular-arrival test samples every 8 ms and verifies
monotonic travel at 200 units/second with a maximum sample step below 1.8 units.
It also verifies that rendering/prediction do not mutate authoritative state.

### Browser recording and timing

Evidence is under `/tmp/focus-pong-oct03-audit/`:

- Original recording inspected: `Screen Recording 2026-10-03 at 08.06.56.mov`
  (36.305 s, 3024×1964, 60-fps container); contact sheet `before.jpg`.
- `pong-after.mp4`: approximately 12 s of actual local release-build gameplay,
  recorded as 234 timed browser screenshots, including horizontal paddle input
  and the server-owned result. This is **not a 60-fps recording** and contains no
  recorded audio. `after-frames/timing.json` preserves capture timestamps.
- `browser-motion.json`: observed mean packet intervals 50.93–51.15 ms;
  worst intervals 80.2–91 ms; zero late packets and no intervals above 100 ms in
  these local runs. Display timing averaged 29.51–33.29 ms.
- `browser-clock.txt`: an independent plain-HTML animation-frame probe, without
  Flutter or Pong, averaged 32.78 ms over 180 frames. This supports a browser/
  environment cadence limitation; **60 FPS on a normal Chromebook is unverified**.

The reproduced instant-input snap has a passing regression and after-recording.
Remote WAN/mobile jitter and sustained 60 FPS still require device acceptance;
local loopback results do not establish those performance claims.

## Presentation

Pong-only dark routes use cyan/coral teams, a vertical viewport-fitted court,
compact controls, explicit top/opponent and bottom/local labels, actual-velocity
trails, hit/point feedback, and reduced-motion handling. The display projection
can expand horizontally while the ball remains circular. Active rallies have no
scroll view. Menus, help and results can scroll when needed for accessibility.

The level selector retains all 15 server definitions, locked/completed states,
replay and saved progress. Results use server-owned outcomes; successful computer
results offer the next level through the existing server authorization path.
The existing short authoritative ready/serve phase remains; no artificial
three-second countdown delays an already-running server match.

The ordinary student dashboard retains its existing application theme.

## Audio

See `PONG_MUSIC_LICENSES.md` for original-file fingerprints, verified CC0 sources,
conversion details and the three bundled assets (4,607,611 bytes total).

- City: Pong home, levels and lobby.
- Empacotatron: computer levels 1–10 and Classic.
- Bouncer: levels 11–15 and Power Battle.
- Two reused music channels crossfade routes and overlap endings; point events
  preserve musical timing. Eight pooled effect channels allow overlapping hits,
  walls and power/point feedback instead of one effect interrupting all others.
- Independent Music/Sound FX controls, master mute and music volume persist
  locally. Muted-first-run behavior is preserved. A Pong gesture activates audio.
- The silent standby music channel is prepared ahead of the loop seam. This
  final preload improvement is covered by the full automated suite; it followed
  the user listening feedback on the earlier local preview.
- Game pause/reconnect suspension and app visibility are separate, preventing
  incoming frames from resuming music in a hidden tab. Route ownership and disposal
  release players/timers. Decode failure does not block play.
- The user listened to the local preview and replied **“Sounds clean”** on
  2026-10-03. This is user-confirmed listening feedback, not a claim that the agent
  heard system audio or that every track/device combination received a playthrough.
- Decoded production peaks: City -5.04 dBFS; Empacotatron -3.53 dBFS; Bouncer
  -9.48 dBFS. Encoded durations: 56.424490, 80.000000 and 93.759615 seconds.

## Executed validation

| Check | Result |
|---|---|
| Existing frontend Pong tests, before edits | 16 passed |
| Existing backend Pong physics/isolation tests, before edits | 46 passed, 0 skipped |
| Full Flutter suite after implementation | 243 passed |
| Full backend suite with disposable loopback MongoDB replica set | 208 passed, 0 skipped |
| Final input/snapshot regression subset | 27 passed |
| Dedicated Pong regression cases (also included in the full suite) | 40 passed |
| Flutter analysis | No issues found |
| `git diff --check` | Passed |
| Optimized production web build | Built; three audio assets match source SHA-256; no test sign-in page; no deployment |
| Six required viewport sizes | Widget layout checks passed at 1920×1080, 1366×768, 1280×800, 1024×768, 768×1024, 390×844 |

Commands/logs: `baseline-flutter.log`, `baseline-backend.log`,
`baseline-motion.log`, `flutter-final.log`, `backend-all.log`, `input-final.log`,
`pong-final.log`, `analyze-final.log`, `production-build.log` in the evidence folder.
Backend tests used `FOCUS_TEST_MONGO_URI` pointing only to `127.0.0.1:27943`.

Tests cover all 15 sequential completions and replay, same-school privacy,
teacher disable, Classic/Power consent, seven powers, reconnect leases, duplicate
persistence prevention, two live streams sharing the seven-point result, and
academic XP isolation. Frontend tests cover orientation, keyboard/touch release,
reduced motion, viewport containment, invitation consent, authoritative result
labels, late packets, interpolation boundaries and audio lifecycle races.

## Local browser acceptance

Synthetic accounts only; no production learner data was changed. The normal
application API/authentication and realtime engine were used. A temporary local
fixture sign-in page obtained normal login tokens for the two battle clients;
this page is outside repository source and is not in the production build.

- Computer: opened Level 1, replayed, observed official completion and saved
  Level 2 unlock; progress remained after refresh. User also exercised Level 2.
- Classic: sent and accepted a same-school invitation. Both clients displayed
  mirrored scores and the same final **7–2** result. A rematch invitation appeared
  and was declined as part of the test.
- Power Battle: explicit invitation/acceptance opened both clients; they displayed
  the same final **7–3** result, Charlie winning. An earlier disconnected attempt
  exhausted the reconnect grace and correctly recorded no winner. Evidence:
  `power-result-bob.txt`, `power-result-charlie.txt`, `browser-power-result.jpg`.
- Local database check: Bob and Charlie each have one win, one loss, two counted
  matches and no active reservation; academic XP remains **20** for each, matching
  their pre-game dashboards. Both remain in the same synthetic school. The
  abandoned match has no winner and did not add a played-result count.
- Music OFF/ON was exercised in the browser audio dialog while Sound FX stayed
  ON. The two battle clients had independent mute preferences.
- General audio feedback: user confirmed clean sound. Autoplay failures are
  non-fatal by design; default mute and route/lifecycle behavior have fake-player
  tests. Native iOS/Android listening and Bluetooth latency remain untested.

## Exact task files

Modified:

1. `lib/features/student/presentation/pong_game_controller.dart`
2. `lib/features/student/presentation/pong_arena_screen.dart`
3. `lib/features/student/presentation/pong_audio.dart`
4. `lib/features/student/presentation/pong_home_screen.dart`
5. `lib/features/student/presentation/pong_lobby_screen.dart`
6. `pubspec.yaml`
7. `test/pong_test.dart`

Added:

8. `lib/features/student/presentation/pong_theme.dart`
9. `lib/features/student/presentation/pong_audio_controls.dart`
10. `test/pong_motion_test.dart`
11. `test/pong_layout_test.dart`
12. `test/pong_audio_test.dart`
13. `assets/music/pong/city.mp3`
14. `assets/music/pong/empacotatron.mp3`
15. `assets/music/pong/bouncer.mp3`
16. `PONG_MUSIC_LICENSES.md`
17. `PONG_POLISH_QA.md`

No backend source files, dependencies, version files or academic files are part
of this change set. AI Pong Championship remains a separate application.
