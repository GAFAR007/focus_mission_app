/**
 * WHAT: Opens a compact school leaderboard with overall and weekly views.
 * WHY: Rankings are an optional view, leaving the learning dashboard focused.
 * HOW: Fetch server-filtered identities through the API service; render clear
 * loading, retry, empty and partial-week states with accessible student rows.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'package:flutter/material.dart';
import '../../core/utils/focus_mission_api.dart';
import '../models/xp_journey.dart';

Future<void> showXpLeaderboard(
  BuildContext context, {
  required FocusMissionApi api,
  required String token,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.85,
    child: XpLeaderboardSheet(api: api, token: token),
  ),
);

class XpLeaderboardSheet extends StatefulWidget {
  const XpLeaderboardSheet({super.key, required this.api, required this.token});
  final FocusMissionApi api;
  final String token;
  @override
  State<XpLeaderboardSheet> createState() => _XpLeaderboardSheetState();
}

class _XpLeaderboardSheetState extends State<XpLeaderboardSheet> {
  String _period = 'overall';
  late Future<XpLeaderboard> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.api.fetchXpLeaderboard(
      token: widget.token,
      period: _period,
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Leaderboard',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Close leaderboard',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const Text('Students in your school'),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'overall', label: Text('Overall')),
            ButtonSegment(value: 'weekly', label: Text('This week')),
          ],
          selected: {_period},
          onSelectionChanged: (value) => setState(() {
            _period = value.single;
            _load();
          }),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<XpLeaderboard>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('The leaderboard could not load.'),
                      TextButton(
                        onPressed: () => setState(_load),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final data = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.myRank != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('My rank #${data.myRank}'),
                    ),
                  if (_period == 'weekly' && data.partialWeek)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Partial week · XP tracked from ${data.trackingStartedAt?.toLocal().toString().split(' ').first ?? 'launch'}.',
                      ),
                    ),
                  if (_period == 'weekly')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'XP earned this week, including score corrections.',
                      ),
                    ),
                  Expanded(
                    child: data.entries.isEmpty
                        ? const Center(child: Text('No active students yet.'))
                        : ListView.separated(
                            itemCount: data.entries.length,
                            separatorBuilder: (_, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = data.entries[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: entry.isYou
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : null,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 38,
                                      child: Text(
                                        '#${entry.rank}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${entry.isYou ? 'YOU · ' : ''}${entry.name}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          if (entry.milestone > 0)
                                            Text(
                                              '${XpJourney.shortLabel(entry.milestone)} milestone',
                                            ),
                                          Text(
                                            '${XpJourney.formatXp(entry.totalXp)} total · ${XpJourney.formatXp(entry.weeklyXp)} this week',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${XpJourney.formatXp(_period == 'weekly' ? entry.weeklyXp : entry.totalXp)} XP',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
