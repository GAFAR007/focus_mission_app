/**
 * WHAT: Student Pong dashboard card and sequential computer level picker.
 * WHY: Students see saved progress and one clear next challenge.
 * HOW: Render server permissions/unlocks and refresh after every arena visit.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import '../../../core/constants/app_palette.dart';
import '../../../core/utils/pong_api.dart';
import '../../../shared/models/pong_models.dart';
import 'pong_theme.dart';
import 'pong_audio.dart';
import 'pong_audio_controls.dart';
import 'pong_arena_screen.dart';
import 'pong_lobby_screen.dart';

class PongDashboardCard extends StatefulWidget {
  const PongDashboardCard({super.key, required this.token, this.api});
  final String token;
  final PongApi? api;
  @override
  State<PongDashboardCard> createState() => _PongDashboardCardState();
}

class _PongDashboardCardState extends State<PongDashboardCard> {
  late final PongApi _api = widget.api ?? PongApi(widget.token);
  late Future<PongProfile> _future = _api.me();
  Future<void> _open(bool computer) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => computer
            ? PongHomeScreen(token: widget.token)
            : PongLobbyScreen(token: widget.token),
      ),
    );
    if (mounted) setState(() => _future = _api.me());
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: FutureBuilder<PongProfile>(
        future: _future,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.sports_esports_rounded,
                    color: AppPalette.navy,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pong Challenge',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (profile == null) ...[
                Text(
                  snapshot.hasError
                      ? 'Pong is temporarily unavailable.'
                      : 'Loading game progress…',
                ),
                if (snapshot.hasError)
                  TextButton(
                    onPressed: () => setState(() => _future = _api.me()),
                    child: const Text('Retry'),
                  ),
              ] else ...[
                Text(
                  'Level ${profile.progress.highestUnlocked} / 15 · Best rally ${profile.progress.bestRally} · Student wins ${profile.progress.multiplayerWins}',
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: profile.progress.completedLevels.length / 15,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 16),
                if (!profile.access.enabled)
                  const Text(
                    'Your teacher has turned Pong off for now. Your progress is saved.',
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: profile.access.computer
                            ? () => _open(true)
                            : null,
                        icon: const Icon(Icons.smart_toy_outlined),
                        label: const Text('Play Computer'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            profile.access.battles &&
                                profile.access.lobbyVisible
                            ? () => _open(false)
                            : null,
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Play Student'),
                      ),
                    ],
                  ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class PongHomeScreen extends StatefulWidget {
  const PongHomeScreen({super.key, required this.token, this.api, this.audio});
  final PongApi? api;
  final PongAudio? audio;
  final String token;
  @override
  State<PongHomeScreen> createState() => _PongHomeScreenState();
}

class _PongHomeScreenState extends State<PongHomeScreen>
    with WidgetsBindingObserver {
  late final PongAudio _audio = widget.audio ?? PongAudio();
  late final PongApi _api = widget.api ?? PongApi(widget.token);
  PongProfile? _profile;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.audio == null) _audio.loadPreferences();
    _audio.select(PongTrack.city);
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.me();
      if (mounted) {
        setState(() {
          _profile = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _play(int level, {String? resume}) async {
    if (_busy) return;
    _audio.activate();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // WHY: A refresh may leave a battle active while the student opens the
      // computer picker. Resume it through its lobby so rematches stay coherent.
      if (resume != null && !(await _api.match(resume)).computer) {
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => PongLobbyScreen(token: widget.token, audio: _audio),
          ),
        );
        await _load();
        if (mounted) setState(() => _busy = false);
        return;
      }
      final handle = resume ?? await _api.computer(level);
      if (!mounted) return;
      final replay = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => PongArenaScreen(
            token: widget.token,
            handle: handle,
            audio: _audio,
          ),
        ),
      );
      await _load();
      if (mounted) setState(() => _busy = false);
      if (replay != null && mounted) await _play(replay);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _audio.background(state != AppLifecycleState.resumed);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.audio == null) _audio.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return PongScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back to Student View',
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Focus Mission Cup Pong',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                PongAudioControls(audio: _audio),
                if (profile?.access.battles == true &&
                    profile?.access.lobbyVisible == true)
                  OutlinedButton.icon(
                    onPressed: () async {
                      _audio.activate();
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PongLobbyScreen(
                            token: widget.token,
                            audio: _audio,
                          ),
                        ),
                      );
                      if (mounted) _load();
                    },
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Challenge a student'),
                  ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'One ball. Fifteen challenges.',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Defend the bottom. Move left or right. Collect boosts as you level up.',
                        ),
                        const SizedBox(height: 20),
                        if (profile != null && profile.levels.isNotEmpty)
                          Text(
                            'UP NEXT · ${profile.levels.firstWhere((l) => l.level == profile.progress.highestUnlocked, orElse: () => profile.levels.last).name}',
                            style: const TextStyle(
                              color: PongColors.cyan,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (profile == null)
                          const LinearProgressIndicator()
                        else ...[
                          LinearProgressIndicator(
                            value: profile.progress.completedLevels.length / 15,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${profile.progress.completedLevels.length} / 15 complete · Best rally ${profile.progress.bestRally}',
                          ),
                          const SizedBox(height: 20),
                          if (!profile.access.enabled ||
                              !profile.access.computer)
                            const Text(
                              'Your teacher has turned Computer Mode off for now. Your progress is saved.',
                            )
                          else
                            FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _play(
                                      profile.progress.highestUnlocked,
                                      resume: profile.activeMatch,
                                    ),
                              icon: Icon(
                                profile.activeMatch == null
                                    ? Icons.play_arrow_rounded
                                    : Icons.refresh,
                              ),
                              label: Text(
                                profile.activeMatch == null
                                    ? 'Play Level ${profile.progress.highestUnlocked}'
                                    : 'Resume your game',
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(child: Text(_error!)),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                if (profile != null) ...[
                  Text(
                    'Your levels',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  for (final level in profile.levels)
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              level.level <= profile.progress.highestUnlocked
                              ? PongColors.cyan
                              : PongColors.surface,
                          child: level.level > profile.progress.highestUnlocked
                              ? const Icon(
                                  Icons.lock_outline,
                                  color: Colors.white54,
                                )
                              : Text(
                                  '${level.level}',
                                  style: const TextStyle(
                                    color: PongColors.background,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                        title: Text(level.name),
                        subtitle: Text(
                          'Level ${level.level} · Get ${level.goal} returns${level.powerUps.isEmpty ? ' · No boosts' : ' · ${level.powerUps.length} ${level.powerUps.length == 1 ? 'boost' : 'boosts'}'}${profile.progress.completedLevels.contains(level.level) ? ' · Completed' : ''}',
                        ),
                        trailing:
                            level.level <= profile.progress.highestUnlocked &&
                                profile.access.enabled &&
                                profile.access.computer
                            ? OutlinedButton(
                                onPressed: _busy || profile.activeMatch != null
                                    ? null
                                    : () => _play(level.level),
                                child: Text(
                                  profile.progress.completedLevels.contains(
                                        level.level,
                                      )
                                      ? 'Replay'
                                      : 'Play',
                                ),
                              )
                            : null,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
