/**
 * WHAT: Same-school Pong lobby with explicit invitations and rematches.
 * WHY: Students choose an opponent without exposing learning or account data.
 * HOW: Poll the scoped lobby while visible and open only an accepted live match.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/utils/pong_api.dart';
import '../../../shared/models/pong_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import 'pong_arena_screen.dart';

class PongLobbyScreen extends StatefulWidget {
  const PongLobbyScreen({super.key, required this.token});
  final String token;
  @override
  State<PongLobbyScreen> createState() => _PongLobbyScreenState();
}

class _PongLobbyScreenState extends State<PongLobbyScreen> {
  late final PongApi _api = PongApi(widget.token);
  final _search = TextEditingController();
  Timer? _poll;
  PongLobby? _lobby;
  String? _error;
  bool _loading = false, _acting = false, _inArena = false, _disabled = false;
  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  Future<void> _load() async {
    if (_loading || _inArena || _disabled) return;
    _loading = true;
    try {
      final profile = await _api.me();
      if (!mounted) return;
      if (profile.activeMatch != null) {
        await _open(profile.activeMatch!);
        return;
      }
      final lobby = await _api.lobby(_search.text.trim());
      if (mounted) {
        setState(() {
          _lobby = lobby;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _disabled = e is PongApiException && e.code == 'PONG_DISABLED';
          if (_disabled) _lobby = null;
        });
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> _open(String handle) async {
    if (_inArena || !mounted) return;
    _inArena = true;
    await Navigator.push(
      context,
      MaterialPageRoute<dynamic>(
        builder: (_) => PongArenaScreen(token: widget.token, handle: handle),
      ),
    );
    _inArena = false;
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _challenge(PongOpponent opponent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Challenge ${opponent.name}?'),
        content: const Text('Pong Battle · First to 7'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Challenge'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _act(() => _api.challenge(opponent.handle));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _search.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScaffold(
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
                      'Pong Lobby',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Play someone from your school · First to 7 · Equal paddles',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _search,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Search students',
                  prefixIcon: Icon(Icons.search),
                  counterText: '',
                ),
                onSubmitted: (_) => _load(),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: () {
                            _disabled = false;
                            _load();
                          },
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_lobby == null && _error == null)
                const LinearProgressIndicator(),
              for (final invite in _lobby?.challenges ?? <PongInvitation>[])
                if (invite.status == 'pending')
                  Card(
                    color: const Color(0xFFE8F1FF),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invite.incoming
                                ? '${invite.name} wants to play Pong'
                                : 'Challenge sent to ${invite.name}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            invite.incoming
                                ? 'First to 7 · ${invite.expiresIn}s to respond'
                                : 'Waiting for response… ${invite.expiresIn}s',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              if (invite.incoming)
                                FilledButton(
                                  onPressed: _acting
                                      ? null
                                      : () => _act(() async {
                                          final match = await _api.respond(
                                            invite.handle,
                                            'accept',
                                          );
                                          if (match != null) await _open(match);
                                        }),
                                  child: const Text('Accept'),
                                ),
                              OutlinedButton(
                                onPressed: _acting
                                    ? null
                                    : () => _act(() async {
                                        await _api.respond(
                                          invite.handle,
                                          invite.incoming
                                              ? 'decline'
                                              : 'cancel',
                                        );
                                      }),
                                child: Text(
                                  invite.incoming
                                      ? 'Decline'
                                      : 'Cancel Challenge',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              if (_lobby != null && _lobby!.students.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No students available here yet. Your teacher can enable Student Battles for your classmates.',
                    ),
                  ),
                ),
              for (final student in _lobby?.students ?? <PongOpponent>[])
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final details = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Level ${student.level} · ${student.wins} wins · ${student.availability}',
                            ),
                          ],
                        );
                        final button = OutlinedButton(
                          onPressed:
                              _acting || student.availability != 'Available'
                              ? null
                              : () => _challenge(student),
                          child: Text(
                            student.availability == 'In game'
                                ? 'Busy'
                                : 'Challenge',
                          ),
                        );
                        return constraints.maxWidth < 440
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  details,
                                  const SizedBox(height: 12),
                                  button,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: details),
                                  const SizedBox(width: 16),
                                  button,
                                ],
                              );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Game results stay separate from your learning progress.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
