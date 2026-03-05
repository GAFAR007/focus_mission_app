/**
 * WHAT:
 * analytics_models defines typed DTOs for teacher analytics chart endpoints.
 * WHY:
 * Keeping analytics payloads in dedicated models prevents loose map parsing in
 * UI widgets and makes chart rendering deterministic.
 * HOW:
 * Parse backend JSON lists into immutable Dart objects with required fields.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

class DailyTrendPoint {
  const DailyTrendPoint({
    required this.date,
    required this.totalXp,
    required this.performanceXp,
    required this.targetXp,
  });

  final String date;
  final int totalXp;
  final int performanceXp;
  final int targetXp;

  factory DailyTrendPoint.fromJson(Map<String, dynamic> json) {
    return DailyTrendPoint(
      date: (json['date'] ?? '').toString(),
      totalXp: _asInt(json['totalXp']),
      performanceXp: _asInt(json['performanceXp']),
      targetXp: _asInt(json['targetXp']),
    );
  }
}

class SessionBreakdown {
  const SessionBreakdown({
    required this.sessionType,
    required this.totalXp,
    required this.avgScore,
    required this.avgFocus,
    required this.sessions,
  });

  final String sessionType;
  final int totalXp;
  final int avgScore;
  final int avgFocus;
  final int sessions;

  factory SessionBreakdown.fromJson(Map<String, dynamic> json) {
    return SessionBreakdown(
      sessionType: (json['sessionType'] ?? '').toString(),
      totalXp: _asInt(json['totalXp']),
      avgScore: _asInt(json['avgScore']),
      avgFocus: _asInt(json['avgFocus']),
      sessions: _asInt(json['sessions']),
    );
  }
}

class SubjectAnalytics {
  const SubjectAnalytics({
    required this.subjectId,
    required this.totalXp,
    required this.avgScore,
    required this.sessions,
  });

  final String subjectId;
  final int totalXp;
  final int avgScore;
  final int sessions;

  factory SubjectAnalytics.fromJson(Map<String, dynamic> json) {
    return SubjectAnalytics(
      subjectId: (json['subjectId'] ?? '').toString(),
      totalXp: _asInt(json['totalXp']),
      avgScore: _asInt(json['avgScore']),
      sessions: _asInt(json['sessions']),
    );
  }
}

class BehaviourDistribution {
  const BehaviourDistribution({
    required this.behaviourStatus,
    required this.count,
  });

  final String behaviourStatus;
  final int count;

  factory BehaviourDistribution.fromJson(Map<String, dynamic> json) {
    return BehaviourDistribution(
      behaviourStatus: (json['behaviourStatus'] ?? '').toString(),
      count: _asInt(json['count']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
