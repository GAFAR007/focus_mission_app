/**
 * WHAT: Describes the long-term 6K journey and 10K stretch milestone.
 * WHY: Daily XP caps are separate from the uncapped cumulative balance.
 * HOW: Derive display progress and the next threshold without changing XP.
 * WHO: Shared presentation models for student dashboard and profile.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

class XpJourney {
  const XpJourney(this.totalXp, {this.achievements = const []});
  final List<XpAchievement> achievements;
  bool isAchieved(int threshold) =>
      totalXp >= threshold || achievements.any((a) => a.threshold == threshold);

  static const goalXp = 6000;
  static const milestones = [500, 1000, 1500, 3000, 5000, goalXp, 10000];
  final int totalXp;

  bool get journeyComplete => isAchieved(goalXp);
  int? get nextMilestone {
    for (final milestone in milestones) {
      if (!isAchieved(milestone)) return milestone;
    }
    return null;
  }

  int get remainingXp => nextMilestone == null ? 0 : nextMilestone! - totalXp;
  int? get highestMilestone {
    for (final milestone in milestones.reversed) {
      if (isAchieved(milestone)) return milestone;
    }
    return null;
  }

  double get progress => (totalXp / goalXp).clamp(0.0, 1.0);

  static String formatXp(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );

  static String shortLabel(int value) => switch (value) {
    1000 => '1K',
    1500 => '1.5K',
    3000 => '3K',
    5000 => '5K',
    6000 => '6K',
    10000 => '10K',
    _ => '$value',
  };
}

class XpAchievement {
  const XpAchievement({
    required this.threshold,
    this.achievedAt,
    this.isLegacy = false,
  });
  final int threshold;
  final DateTime? achievedAt;
  final bool isLegacy;
  factory XpAchievement.fromJson(Map<String, dynamic> json) => XpAchievement(
    threshold: (json['threshold'] as num).toInt(),
    achievedAt: DateTime.tryParse('${json['achievedAt'] ?? ''}'),
    isLegacy: json['isLegacy'] == true,
  );
}

class XpLeaderboardEntry {
  XpLeaderboardEntry.fromJson(Map<String, dynamic> json)
    : rank = (json['rank'] as num).toInt(),
      name = json['name'] as String,
      totalXp = (json['totalXp'] as num).toInt(),
      weeklyXp = (json['weeklyXp'] as num).toInt(),
      milestone = (json['milestone'] as num).toInt(),
      isYou = json['isYou'] == true;
  final int rank, totalXp, weeklyXp, milestone;
  final String name;
  final bool isYou;
}

class XpLeaderboard {
  XpLeaderboard.fromJson(Map<String, dynamic> json)
    : entries = (json['entries'] as List)
          .map((e) => XpLeaderboardEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      myRank = (json['myRank'] as num?)?.toInt(),
      partialWeek = json['partialWeek'] == true,
      trackingStartedAt = DateTime.tryParse(
        '${json['trackingStartedAt'] ?? ''}',
      );
  final List<XpLeaderboardEntry> entries;
  final int? myRank;
  final bool partialWeek;
  final DateTime? trackingStartedAt;
}
