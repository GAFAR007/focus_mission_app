/**
 * WHAT: Per-student Pong controls shared by teacher and management screens.
 * WHY: Staff can permit solo play independently from student battles.
 * HOW: Load persisted access and save one toggle through the authorized API.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import '../../core/utils/pong_api.dart';
import '../models/pong_models.dart';

class PongAccessPanel extends StatefulWidget {
  const PongAccessPanel({
    super.key,
    required this.token,
    required this.studentId,
    this.api,
  });
  final String token, studentId;
  final PongApi? api;
  @override
  State<PongAccessPanel> createState() => _PongAccessPanelState();
}

class _PongAccessPanelState extends State<PongAccessPanel> {
  late final PongApi _api = widget.api ?? PongApi(widget.token);
  PongAccess? _access;
  String? _error;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PongAccessPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId) {
      _access = null;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.studentId;
    try {
      final data = await _api.request('GET', '/access/$id');
      if (mounted && id == widget.studentId) {
        setState(() {
          _access = PongAccess.fromJson(pongMap(data['access']));
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && id == widget.studentId) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _save(String key, bool value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final id = widget.studentId;
    try {
      final data = await _api.request('PATCH', '/access/$id', {key: value});
      if (mounted && id == widget.studentId) {
        setState(() => _access = PongAccess.fromJson(pongMap(data['access'])));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ExpansionTile(
      leading: const Icon(Icons.sports_esports_outlined),
      title: const Text('Pong Challenge · Game access'),
      subtitle: Text(
        _access == null
            ? 'Loading game access…'
            : _access!.enabled
            ? 'Game on · ${_access!.battles ? 'Student battles on' : 'Student battles off'}'
            : 'Game off',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (_access != null) ...[
          for (final entry in {
            'enabled': 'Game Access',
            'computer': 'Computer Mode',
            'battles': 'Student Battles',
            'lobbyVisible': 'Visible in Pong Lobby',
          }.entries)
            SwitchListTile.adaptive(
              title: Text(entry.value),
              value: _access!.toJson()[entry.key] as bool,
              onChanged: _saving ? null : (value) => _save(entry.key, value),
            ),
          const Text('Turning a game off keeps saved progress.'),
        ],
        if (_saving) const LinearProgressIndicator(),
        if (_error != null)
          Row(
            children: [
              Expanded(child: Text(_error!)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
      ],
    ),
  );
}
