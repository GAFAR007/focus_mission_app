/**
 * WHAT: Shows the application version and a permanent What's New history.
 * WHY: Students and staff need concise release notes without technical details.
 * HOW: Render generated canonical metadata and remember the last viewed version
 * per account on this device. Optional preference failures never block learning.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/release_history.g.dart';
import '../../core/utils/auth_session_store.dart';

class ReleaseHistoryButton extends StatefulWidget {
  const ReleaseHistoryButton({super.key, this.userId, this.history});

  final String? userId;
  final Map<String, dynamic>? history;

  @override
  State<ReleaseHistoryButton> createState() => _ReleaseHistoryButtonState();
}

class _ReleaseHistoryButtonState extends State<ReleaseHistoryButton> {
  late final Map<String, dynamic> _history =
      widget.history ??
      jsonDecode(utf8.decode(base64Decode(releaseHistoryBase64)))
          as Map<String, dynamic>;
  bool _isNew = false;
  String? _preferenceKey;

  String get _version => _history['version'] as String;

  @override
  void initState() {
    super.initState();
    _loadViewedVersion();
  }

  @override
  void didUpdateWidget(covariant ReleaseHistoryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) _loadViewedVersion();
  }

  Future<void> _loadViewedVersion() async {
    try {
      final userId = widget.userId ?? await AuthSessionStore().cachedUserId();
      final key = 'focusMission.releaseViewed.${userId ?? 'guest'}';
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _preferenceKey = key;
        _isNew = prefs.getString(key) != _version;
      });
    } catch (error) {
      // WHY: Release awareness is optional and cannot interrupt a mission.
      debugPrint(
        'Release history preferences unavailable: ${error.runtimeType}',
      );
    }
  }

  Future<void> _openHistory() async {
    // Capture the reader before opening so switching accounts cannot mark a
    // different account's release history as viewed.
    final key = _preferenceKey;
    setState(() => _isNew = false);
    if (key != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, _version);
      } catch (error) {
        debugPrint(
          'Release history preference was not saved: ${error.runtimeType}',
        );
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "What's New",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close release history',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  itemCount: (_history['releases'] as List).length,
                  separatorBuilder: (_, _) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  itemBuilder: (context, index) => _ReleaseEntry(
                    entry:
                        (_history['releases'] as List)[index]
                            as Map<String, dynamic>,
                    current: index == 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: 48,
      child: Center(
        child: TextButton(
          onPressed: _openHistory,
          child: Text('v$_version${_isNew ? ' • New' : ''}'),
        ),
      ),
    ),
  );
}

class _ReleaseEntry extends StatelessWidget {
  const _ReleaseEntry({required this.entry, required this.current});

  final Map<String, dynamic> entry;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final changes = entry['changes'] as Map<String, dynamic>;
    final releasedAt = DateTime.tryParse(entry['releasedAt']?.toString() ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'v${entry['version']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (current)
              Chip(
                label: const Text('Current'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if (releasedAt != null)
          Text(MaterialLocalizations.of(context).formatMediumDate(releasedAt)),
        const SizedBox(height: 8),
        Text(
          entry['title'] as String,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final category in ['new', 'improved', 'fixed'])
          if ((changes[category] as List).isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '${category[0].toUpperCase()}${category.substring(1)}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            for (final note in changes[category] as List)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $note'),
              ),
          ],
      ],
    );
  }
}
