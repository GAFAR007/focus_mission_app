/**
 * WHAT:
 * Shared frontend models for auth, timetable, missions, and criterion
 * progression payloads returned by the Focus Mission backend.
 * WHY:
 * The Flutter app needs typed models so ADHD-focused progression screens can
 * render stable state transitions without scattering raw JSON parsing logic.
 * HOW:
 * Decode API payloads into immutable Dart objects with small helper parsers and
 * progression-specific getters for student and teacher flows.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    this.email,
    this.role,
    this.yearGroup,
    this.subjectSpecialty,
    this.subjectSpecialties = const [],
    this.isPlaceholder = false,
    this.avatar,
    this.avatarSeed,
    this.xp = 0,
    this.streak = 0,
    this.streakBadgeUnlocked = false,
    this.firstLoginAt,
    this.lastLoginAt,
    this.loginDayCount = 0,
    this.daysSinceFirstLogin = 0,
    this.isArchived = false,
    this.archivedAt,
    this.preferredDifficulty,
    this.assignedStudents = const [],
  });

  final String id;
  final String name;
  final String? email;
  final String? role;
  final String? yearGroup;
  final String? subjectSpecialty;
  final List<String> subjectSpecialties;
  final bool isPlaceholder;
  final String? avatar;
  final String? avatarSeed;
  final int xp;
  final int streak;
  final bool streakBadgeUnlocked;
  final String? firstLoginAt;
  final String? lastLoginAt;
  final int loginDayCount;
  final int daysSinceFirstLogin;
  final bool isArchived;
  final String? archivedAt;
  final String? preferredDifficulty;
  final List<String> assignedStudents;

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? yearGroup,
    String? subjectSpecialty,
    List<String>? subjectSpecialties,
    bool? isPlaceholder,
    String? avatar,
    String? avatarSeed,
    int? xp,
    int? streak,
    bool? streakBadgeUnlocked,
    String? firstLoginAt,
    String? lastLoginAt,
    int? loginDayCount,
    int? daysSinceFirstLogin,
    bool? isArchived,
    String? archivedAt,
    String? preferredDifficulty,
    List<String>? assignedStudents,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      yearGroup: yearGroup ?? this.yearGroup,
      subjectSpecialty: subjectSpecialty ?? this.subjectSpecialty,
      subjectSpecialties: subjectSpecialties ?? this.subjectSpecialties,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      avatar: avatar ?? this.avatar,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      streakBadgeUnlocked: streakBadgeUnlocked ?? this.streakBadgeUnlocked,
      firstLoginAt: firstLoginAt ?? this.firstLoginAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      loginDayCount: loginDayCount ?? this.loginDayCount,
      daysSinceFirstLogin: daysSinceFirstLogin ?? this.daysSinceFirstLogin,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      preferredDifficulty: preferredDifficulty ?? this.preferredDifficulty,
      assignedStudents: assignedStudents ?? this.assignedStudents,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString(),
      yearGroup: json['yearGroup']?.toString(),
      subjectSpecialty: json['subjectSpecialty']?.toString(),
      subjectSpecialties: _asStringList(json['subjectSpecialties']),
      isPlaceholder: json['isPlaceholder'] == true,
      avatar: json['avatar']?.toString(),
      avatarSeed: json['avatarSeed']?.toString(),
      xp: _asInt(json['xp']),
      streak: _asInt(json['streak']),
      streakBadgeUnlocked: json['streakBadgeUnlocked'] == true,
      firstLoginAt: json['firstLoginAt']?.toString(),
      lastLoginAt: json['lastLoginAt']?.toString(),
      loginDayCount: _asInt(json['loginDayCount']),
      daysSinceFirstLogin: _asInt(json['daysSinceFirstLogin']),
      isArchived: json['isArchived'] == true,
      archivedAt: json['archivedAt']?.toString(),
      preferredDifficulty: json['preferredDifficulty']?.toString(),
      assignedStudents: _asStringList(json['assignedStudents']),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.loginMeta = const LoginMeta(),
  });

  final String token;
  final AppUser user;
  final LoginMeta loginMeta;

  AuthSession copyWith({String? token, AppUser? user, LoginMeta? loginMeta}) {
    return AuthSession(
      token: token ?? this.token,
      user: user ?? this.user,
      loginMeta: loginMeta ?? this.loginMeta,
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: (json['token'] ?? '').toString(),
      user: AppUser.fromJson(_asMap(json['user'])),
      loginMeta: LoginMeta.fromJson(_asMap(json['loginMeta'])),
    );
  }
}

class LoginMeta {
  const LoginMeta({
    this.dailyLoginRewardGranted = false,
    this.dailyLoginXpAwarded = 0,
    this.dateKey = '',
  });

  final bool dailyLoginRewardGranted;
  final int dailyLoginXpAwarded;
  final String dateKey;

  factory LoginMeta.fromJson(Map<String, dynamic> json) {
    return LoginMeta(
      dailyLoginRewardGranted: json['dailyLoginRewardGranted'] == true,
      dailyLoginXpAwarded: _asInt(json['dailyLoginXpAwarded']),
      dateKey: (json['dateKey'] ?? '').toString(),
    );
  }
}

class SubjectSummary {
  const SubjectSummary({
    required this.id,
    required this.name,
    this.icon,
    this.color,
  });

  final String id;
  final String name;
  final String? icon;
  final String? color;

  factory SubjectSummary.fromJson(Map<String, dynamic> json) {
    return SubjectSummary(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
    );
  }
}

class TeacherSummary {
  const TeacherSummary({
    required this.id,
    required this.name,
    this.email,
    this.avatar,
    this.role,
    this.subjectSpecialty,
    this.subjectSpecialties = const [],
  });

  final String id;
  final String name;
  final String? email;
  final String? avatar;
  final String? role;
  final String? subjectSpecialty;
  final List<String> subjectSpecialties;

  factory TeacherSummary.fromJson(Map<String, dynamic> json) {
    return TeacherSummary(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: json['email']?.toString(),
      avatar: json['avatar']?.toString(),
      role: json['role']?.toString(),
      subjectSpecialty: json['subjectSpecialty']?.toString(),
      subjectSpecialties: _asStringList(json['subjectSpecialties']),
    );
  }
}

class ManagementSessionCoverAssignment {
  const ManagementSessionCoverAssignment({
    required this.id,
    required this.dateKey,
    required this.sessionType,
    required this.reason,
    this.subject,
    this.plannedTeacher,
    this.coverStaff,
  });

  final String id;
  final String dateKey;
  final String sessionType;
  final String reason;
  final SubjectSummary? subject;
  final TeacherSummary? plannedTeacher;
  final TeacherSummary? coverStaff;

  factory ManagementSessionCoverAssignment.fromJson(
    Map<String, dynamic> json,
  ) {
    return ManagementSessionCoverAssignment(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      dateKey: (json['dateKey'] ?? '').toString(),
      sessionType: (json['sessionType'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      subject: _asNullableMap(json['subject']) == null
          ? null
          : SubjectSummary.fromJson(_asMap(json['subject'])),
      plannedTeacher: _asNullableMap(json['plannedTeacher']) == null
          ? null
          : TeacherSummary.fromJson(_asMap(json['plannedTeacher'])),
      coverStaff: _asNullableMap(json['coverStaff']) == null
          ? null
          : TeacherSummary.fromJson(_asMap(json['coverStaff'])),
    );
  }
}

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.subjectName,
    required this.completedQuestions,
    required this.focusScore,
    required this.sessionType,
  });

  final String id;
  final String subjectName;
  final int completedQuestions;
  final int focusScore;
  final String sessionType;

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    final subject = _asMap(json['subjectId']);

    return SessionSummary(
      id: (json['_id'] ?? '').toString(),
      subjectName: (subject['name'] ?? 'Mission').toString(),
      completedQuestions: _asInt(json['completedQuestions']),
      focusScore: _asInt(json['focusScore']),
      sessionType: (json['sessionType'] ?? '').toString(),
    );
  }
}

class TodaySchedule {
  const TodaySchedule({
    required this.day,
    required this.room,
    required this.morningMission,
    required this.afternoonMission,
    this.morningTeacher,
    this.afternoonTeacher,
  });

  final String day;
  final String room;
  final SubjectSummary morningMission;
  final SubjectSummary afternoonMission;
  final TeacherSummary? morningTeacher;
  final TeacherSummary? afternoonTeacher;

  factory TodaySchedule.fromJson(Map<String, dynamic> json) {
    return TodaySchedule(
      day: (json['day'] ?? '').toString(),
      room: (json['room'] ?? '').toString(),
      morningMission: SubjectSummary.fromJson(_asMap(json['morningMission'])),
      afternoonMission: SubjectSummary.fromJson(
        _asMap(json['afternoonMission']),
      ),
      morningTeacher: _asNullableMap(json['morningTeacher']) == null
          ? null
          : TeacherSummary.fromJson(_asMap(json['morningTeacher'])),
      afternoonTeacher: _asNullableMap(json['afternoonTeacher']) == null
          ? null
          : TeacherSummary.fromJson(_asMap(json['afternoonTeacher'])),
    );
  }
}

class ManagementPlannedSession {
  const ManagementPlannedSession({
    required this.sessionType,
    required this.hasScheduledLesson,
    required this.missions,
    this.subject,
    this.teacher,
    this.coverAssignment,
  });

  final String sessionType;
  final bool hasScheduledLesson;
  final SubjectSummary? subject;
  final TeacherSummary? teacher;
  final ManagementSessionCoverAssignment? coverAssignment;
  final List<MissionPayload> missions;

  factory ManagementPlannedSession.fromJson(Map<String, dynamic> json) {
    return ManagementPlannedSession(
      sessionType: (json['sessionType'] ?? '').toString(),
      hasScheduledLesson: json['hasScheduledLesson'] == true,
      subject: _asNullableMap(json['subject']) == null
          ? null
          : SubjectSummary.fromJson(_asMap(json['subject'])),
      teacher: _asNullableMap(json['teacher']) == null
          ? null
          : TeacherSummary.fromJson(_asMap(json['teacher'])),
      coverAssignment: _asNullableMap(json['coverAssignment']) == null
          ? null
          : ManagementSessionCoverAssignment.fromJson(
              _asMap(json['coverAssignment']),
            ),
      missions: (json['missions'] as List<dynamic>? ?? const [])
          .map((item) => MissionPayload.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class ManagementDayPlan {
  const ManagementDayPlan({
    required this.dateKey,
    required this.weekday,
    required this.hasTimetableEntry,
    required this.room,
    required this.morning,
    required this.afternoon,
    this.availableCoverStaff = const [],
    this.student,
  });

  final String dateKey;
  final String weekday;
  final bool hasTimetableEntry;
  final String room;
  final AppUser? student;
  final List<TeacherSummary> availableCoverStaff;
  final ManagementPlannedSession morning;
  final ManagementPlannedSession afternoon;

  int get totalMissionCount =>
      morning.missions.length + afternoon.missions.length;

  factory ManagementDayPlan.fromJson(Map<String, dynamic> json) {
    return ManagementDayPlan(
      dateKey: (json['dateKey'] ?? '').toString(),
      weekday: (json['weekday'] ?? '').toString(),
      hasTimetableEntry: json['hasTimetableEntry'] == true,
      room: (json['room'] ?? '').toString(),
      student: _asNullableMap(json['student']) == null
          ? null
          : AppUser.fromJson(_asMap(json['student'])),
      availableCoverStaff:
          (json['availableCoverStaff'] as List<dynamic>? ?? const [])
              .map((item) => TeacherSummary.fromJson(_asMap(item)))
              .toList(growable: false),
      morning: ManagementPlannedSession.fromJson(_asMap(json['morning'])),
      afternoon: ManagementPlannedSession.fromJson(_asMap(json['afternoon'])),
    );
  }
}

class StudentDashboardData {
  const StudentDashboardData({
    required this.student,
    required this.recentSessions,
    required this.dailyXp,
    required this.subjectProgress,
    required this.subjectCertification,
    required this.todayStandalonePapers,
    this.today,
  });

  final AppUser student;
  final TodaySchedule? today;
  final List<SessionSummary> recentSessions;
  final DailyXpSummary dailyXp;
  final List<SubjectProgressSummary> subjectProgress;
  final List<SubjectCertificationSummary> subjectCertification;
  final List<StandalonePaperAvailability> todayStandalonePapers;

  factory StudentDashboardData.fromJson(Map<String, dynamic> json) {
    final sessions = (json['recentSessions'] as List<dynamic>? ?? const [])
        .map((item) => SessionSummary.fromJson(_asMap(item)))
        .toList();

    return StudentDashboardData(
      student: AppUser.fromJson(_asMap(json['student'])),
      dailyXp: DailyXpSummary.fromJson(_asMap(json['dailyXp'])),
      subjectProgress: (json['subjectProgress'] as List<dynamic>? ?? const [])
          .map((item) => SubjectProgressSummary.fromJson(_asMap(item)))
          .toList(growable: false),
      subjectCertification:
          (json['subjectCertification'] as List<dynamic>? ?? const [])
              .map((item) => SubjectCertificationSummary.fromJson(_asMap(item)))
              .toList(growable: false),
      todayStandalonePapers:
          (json['todayStandalonePapers'] as List<dynamic>? ?? const [])
              .map((item) => StandalonePaperAvailability.fromJson(_asMap(item)))
              .toList(growable: false),
      today: _asNullableMap(json['today']) == null
          ? null
          : TodaySchedule.fromJson(_asMap(json['today'])),
      recentSessions: sessions,
    );
  }
}

class DailyXpSummary {
  const DailyXpSummary({
    required this.dateKey,
    required this.dailyLoginXp,
    required this.attendanceXp,
    required this.challengeXp,
    required this.assessmentXp,
    required this.performanceXp,
    required this.performanceXpCap,
    required this.targetXp,
    required this.targetXpCap,
    required this.weeklyTargetXp,
    required this.weeklyTargetXpCap,
    required this.totalXp,
    required this.totalXpCap,
    required this.weekKey,
    this.performanceXpAwarded = 0,
    this.subjectCompletionBonusXp = 0,
  });

  final String dateKey;
  final int dailyLoginXp;
  final int attendanceXp;
  final int challengeXp;
  final int assessmentXp;
  final int performanceXp;
  final int performanceXpCap;
  final int targetXp;
  final int targetXpCap;
  final int weeklyTargetXp;
  final int weeklyTargetXpCap;
  final int totalXp;
  final int totalXpCap;
  final String weekKey;
  final int performanceXpAwarded;
  final int subjectCompletionBonusXp;

  factory DailyXpSummary.fromJson(Map<String, dynamic> json) {
    return DailyXpSummary(
      dateKey: (json['dateKey'] ?? '').toString(),
      dailyLoginXp: _asInt(json['dailyLoginXp']),
      attendanceXp: _asInt(json['attendanceXp']),
      challengeXp: _asInt(json['challengeXp']),
      assessmentXp: _asInt(json['assessmentXp']),
      performanceXp: _asInt(json['performanceXp']),
      performanceXpCap: _asInt(json['performanceXpCap']) > 0
          ? _asInt(json['performanceXpCap'])
          : 100,
      targetXp: _asInt(json['targetXp']),
      targetXpCap: _asInt(json['targetXpCap']) > 0
          ? _asInt(json['targetXpCap'])
          : 100,
      weeklyTargetXp: _asInt(json['weeklyTargetXp']),
      weeklyTargetXpCap: _asInt(json['weeklyTargetXpCap']) > 0
          ? _asInt(json['weeklyTargetXpCap'])
          : 500,
      totalXp: _asInt(json['totalXp']),
      totalXpCap: _asInt(json['totalXpCap']) > 0
          ? _asInt(json['totalXpCap'])
          : 200,
      weekKey: (json['weekKey'] ?? '').toString(),
      performanceXpAwarded: _asInt(json['performanceXpAwarded']),
      subjectCompletionBonusXp: _asInt(json['subjectCompletionBonusXp']),
    );
  }
}

class SubjectProgressSummary {
  const SubjectProgressSummary({
    required this.subjectId,
    required this.subjectName,
    required this.totalAssessments,
    required this.completedAssessments,
    required this.averageScore,
    required this.completionPercentage,
    required this.badgeUnlocked,
    this.subjectIcon,
    this.subjectColor,
  });

  final String subjectId;
  final String subjectName;
  final String? subjectIcon;
  final String? subjectColor;
  final int totalAssessments;
  final int completedAssessments;
  final int averageScore;
  final int completionPercentage;
  final bool badgeUnlocked;

  factory SubjectProgressSummary.fromJson(Map<String, dynamic> json) {
    return SubjectProgressSummary(
      subjectId: (json['subjectId'] ?? '').toString(),
      subjectName: (json['subjectName'] ?? '').toString(),
      subjectIcon: json['subjectIcon']?.toString(),
      subjectColor: json['subjectColor']?.toString(),
      totalAssessments: _asInt(json['totalAssessments']),
      completedAssessments: _asInt(json['completedAssessments']),
      averageScore: _asInt(json['averageScore']),
      completionPercentage: _asInt(json['completionPercentage']),
      badgeUnlocked: json['badgeUnlocked'] == true,
    );
  }
}

class CertificationEvidenceRow {
  const CertificationEvidenceRow({
    required this.taskCode,
    required this.status,
    required this.bestScorePercent,
    required this.bestMissionId,
    required this.bestResultPackageId,
    required this.missionType,
    required this.completedAt,
    required this.reason,
  });

  final String taskCode;
  final String status;
  final double bestScorePercent;
  final String bestMissionId;
  final String bestResultPackageId;
  final String missionType;
  final String? completedAt;
  final String reason;

  bool get isPassed => status == 'passed';
  bool get isPendingReview => status == 'pending_review';
  bool get isNotStarted => status == 'not_started';

  factory CertificationEvidenceRow.fromJson(Map<String, dynamic> json) {
    return CertificationEvidenceRow(
      taskCode: (json['taskCode'] ?? '').toString(),
      status: (json['status'] ?? 'not_started').toString(),
      bestScorePercent: _asDouble(json['bestScorePercent']),
      bestMissionId: (json['bestMissionId'] ?? '').toString(),
      bestResultPackageId: (json['bestResultPackageId'] ?? '').toString(),
      missionType: (json['missionType'] ?? '').toString(),
      completedAt: json['completedAt']?.toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

class SubjectCertificationSummary {
  const SubjectCertificationSummary({
    required this.subjectId,
    required this.subjectName,
    required this.subjectIcon,
    required this.subjectColor,
    required this.certificationEnabled,
    required this.certificationLabel,
    required this.requiredTaskCodes,
    required this.passedTaskCodes,
    required this.remainingTaskCodes,
    required this.completionPercentage,
    required this.averagePassedScorePercent,
    required this.certificateUnlocked,
    required this.awardRecorded,
    required this.evidenceRows,
    required this.planSource,
    required this.planId,
    required this.planVersion,
    required this.planUpdatedAt,
    required this.planChangeReason,
  });

  final String subjectId;
  final String subjectName;
  final String subjectIcon;
  final String subjectColor;
  final bool certificationEnabled;
  final String certificationLabel;
  final List<String> requiredTaskCodes;
  final List<String> passedTaskCodes;
  final List<String> remainingTaskCodes;
  final int completionPercentage;
  final double averagePassedScorePercent;
  final bool certificateUnlocked;
  final bool awardRecorded;
  final List<CertificationEvidenceRow> evidenceRows;
  final String planSource;
  final String? planId;
  final int? planVersion;
  final DateTime? planUpdatedAt;
  final String? planChangeReason;

  factory SubjectCertificationSummary.fromJson(Map<String, dynamic> json) {
    return SubjectCertificationSummary(
      subjectId: (json['subjectId'] ?? '').toString(),
      subjectName: (json['subjectName'] ?? '').toString(),
      subjectIcon: (json['subjectIcon'] ?? '').toString(),
      subjectColor: (json['subjectColor'] ?? '').toString(),
      certificationEnabled: json['certificationEnabled'] == true,
      certificationLabel: (json['certificationLabel'] ?? '').toString(),
      requiredTaskCodes: _asStringList(json['requiredTaskCodes']),
      passedTaskCodes: _asStringList(json['passedTaskCodes']),
      remainingTaskCodes: _asStringList(json['remainingTaskCodes']),
      completionPercentage: _asInt(json['completionPercentage']),
      averagePassedScorePercent: _asDouble(json['averagePassedScorePercent']),
      certificateUnlocked: json['certificateUnlocked'] == true,
      awardRecorded: json['awardRecorded'] == true,
      evidenceRows: (json['evidenceRows'] as List<dynamic>? ?? const [])
          .map((item) => CertificationEvidenceRow.fromJson(_asMap(item)))
          .toList(growable: false),
      planSource: (json['planSource'] ?? '').toString(),
      planId: _asOptionalString(json['planId']),
      planVersion: _asNullableInt(json['planVersion']),
      planUpdatedAt: _asNullableDateTime(json['planUpdatedAt']),
      planChangeReason: _asOptionalString(json['planChangeReason']),
    );
  }
}

class StudentSubjectReportSummary {
  const StudentSubjectReportSummary({
    required this.subjectId,
    required this.subjectName,
    required this.subjectIcon,
    required this.subjectColor,
    required this.assessmentCompletionPercentage,
    required this.assessmentAverageScore,
    required this.certificationEnabled,
    required this.certificationCompletionPercentage,
    required this.passedTaskFocusCount,
    required this.requiredTaskFocusCount,
    required this.remainingTaskCodes,
    required this.certificateUnlocked,
  });

  final String subjectId;
  final String subjectName;
  final String subjectIcon;
  final String subjectColor;
  final int assessmentCompletionPercentage;
  final int assessmentAverageScore;
  final bool certificationEnabled;
  final int certificationCompletionPercentage;
  final int passedTaskFocusCount;
  final int requiredTaskFocusCount;
  final List<String> remainingTaskCodes;
  final bool certificateUnlocked;
}

class StudentSubjectMissionHistoryItem {
  const StudentSubjectMissionHistoryItem({
    required this.missionId,
    required this.resultPackageId,
    required this.title,
    required this.missionType,
    required this.taskCodes,
    required this.assignedDate,
    required this.submittedAt,
    required this.scorePercent,
    required this.xpAwarded,
    required this.certificationEligible,
    required this.certificationCounted,
    required this.certificationPassStatus,
    required this.statusLabel,
  });

  final String missionId;
  final String resultPackageId;
  final String title;
  final String missionType;
  final List<String> taskCodes;
  final String assignedDate;
  final String? submittedAt;
  final int scorePercent;
  final int xpAwarded;
  final bool certificationEligible;
  final bool certificationCounted;
  final String certificationPassStatus;
  final String statusLabel;

  factory StudentSubjectMissionHistoryItem.fromJson(Map<String, dynamic> json) {
    return StudentSubjectMissionHistoryItem(
      missionId: (json['missionId'] ?? '').toString(),
      resultPackageId: (json['resultPackageId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      missionType: (json['missionType'] ?? '').toString(),
      taskCodes: _asStringList(json['taskCodes']),
      assignedDate: (json['assignedDate'] ?? '').toString(),
      submittedAt: json['submittedAt']?.toString(),
      scorePercent: _asInt(json['scorePercent']),
      xpAwarded: _asInt(json['xpAwarded']),
      certificationEligible: json['certificationEligible'] == true,
      certificationCounted: json['certificationCounted'] == true,
      certificationPassStatus:
          (json['certificationPassStatus'] ?? 'not_eligible').toString(),
      statusLabel: (json['statusLabel'] ?? '').toString(),
    );
  }
}

class StudentSubjectReportData {
  const StudentSubjectReportData({
    required this.subject,
    required this.assessmentProgress,
    required this.certification,
    required this.missionHistory,
  });

  final SubjectSummary subject;
  final SubjectProgressSummary? assessmentProgress;
  final SubjectCertificationSummary certification;
  final List<StudentSubjectMissionHistoryItem> missionHistory;

  factory StudentSubjectReportData.fromJson(Map<String, dynamic> json) {
    return StudentSubjectReportData(
      subject: SubjectSummary.fromJson(_asMap(json['subject'])),
      assessmentProgress: _asNullableMap(json['assessmentProgress']) == null
          ? null
          : SubjectProgressSummary.fromJson(_asMap(json['assessmentProgress'])),
      certification: SubjectCertificationSummary.fromJson(
        _asMap(json['certification']),
      ),
      missionHistory: (json['missionHistory'] as List<dynamic>? ?? const [])
          .map(
            (item) => StudentSubjectMissionHistoryItem.fromJson(_asMap(item)),
          )
          .toList(growable: false),
    );
  }
}

class SubjectCertificationSettings {
  const SubjectCertificationSettings({
    required this.subjectId,
    required this.subjectName,
    required this.subjectIcon,
    required this.subjectColor,
    required this.certificationEnabled,
    required this.requiredCertificationTaskCodes,
    required this.certificationLabel,
  });

  final String subjectId;
  final String subjectName;
  final String subjectIcon;
  final String subjectColor;
  final bool certificationEnabled;
  final List<String> requiredCertificationTaskCodes;
  final String certificationLabel;

  factory SubjectCertificationSettings.fromJson(Map<String, dynamic> json) {
    return SubjectCertificationSettings(
      subjectId: (json['subjectId'] ?? '').toString(),
      subjectName: (json['subjectName'] ?? '').toString(),
      subjectIcon: (json['subjectIcon'] ?? '').toString(),
      subjectColor: (json['subjectColor'] ?? '').toString(),
      certificationEnabled: json['certificationEnabled'] == true,
      requiredCertificationTaskCodes: _asStringList(
        json['requiredCertificationTaskCodes'],
      ),
      certificationLabel: (json['certificationLabel'] ?? '').toString(),
    );
  }
}

class StudentSummary {
  const StudentSummary({
    required this.id,
    required this.name,
    required this.xp,
    required this.streak,
    this.yearGroup = '',
    this.isArchived = false,
    this.archivedAt,
  });

  final String id;
  final String name;
  final int xp;
  final int streak;
  final String yearGroup;
  final bool isArchived;
  final String? archivedAt;

  factory StudentSummary.fromJson(Map<String, dynamic> json) {
    return StudentSummary(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      xp: _asInt(json['xp']),
      streak: _asInt(json['streak']),
      yearGroup: (json['yearGroup'] ?? '').toString(),
      isArchived: json['isArchived'] == true,
      archivedAt: json['archivedAt']?.toString(),
    );
  }
}

class MissionQuestion {
  const MissionQuestion({
    required this.id,
    required this.answerMode,
    required this.learningText,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.expectedAnswer,
    required this.minWordCount,
  });

  final String id;
  final String answerMode;
  final String learningText;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String expectedAnswer;
  final int minWordCount;

  bool get isShortAnswerTheory => answerMode == 'short_answer';

  MissionQuestion copyWith({
    String? id,
    String? answerMode,
    String? learningText,
    String? prompt,
    List<String>? options,
    int? correctIndex,
    String? explanation,
    String? expectedAnswer,
    int? minWordCount,
  }) {
    return MissionQuestion(
      id: id ?? this.id,
      answerMode: answerMode ?? this.answerMode,
      learningText: learningText ?? this.learningText,
      prompt: prompt ?? this.prompt,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      explanation: explanation ?? this.explanation,
      expectedAnswer: expectedAnswer ?? this.expectedAnswer,
      minWordCount: minWordCount ?? this.minWordCount,
    );
  }

  factory MissionQuestion.fromJson(Map<String, dynamic> json) {
    final answerMode = (json['answerMode'] ?? '').toString().trim();
    return MissionQuestion(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      answerMode: answerMode.isNotEmpty
          ? answerMode
          : ((json['draftFormat'] ?? '').toString().trim().toUpperCase() ==
                    'THEORY'
                ? 'short_answer'
                : 'multiple_choice'),
      learningText:
          (json['learningText'] ??
                  json['lessonText'] ??
                  json['explanation'] ??
                  '')
              .toString(),
      prompt: (json['prompt'] ?? '').toString(),
      options: _asStringList(json['options']),
      correctIndex: _asInt(json['correctIndex']),
      explanation: (json['explanation'] ?? '').toString(),
      expectedAnswer: (json['expectedAnswer'] ?? json['explanation'] ?? '')
          .toString(),
      minWordCount: _asInt(json['minWordCount']),
    );
  }
}

class MissionSubject {
  const MissionSubject({
    required this.id,
    required this.name,
    this.icon,
    this.color,
  });

  final String id;
  final String name;
  final String? icon;
  final String? color;

  factory MissionSubject.fromJson(Map<String, dynamic> json) {
    return MissionSubject(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
    );
  }
}

class MissionPayload {
  const MissionPayload({
    required this.id,
    required this.title,
    required this.teacherNote,
    required this.sourceUnitText,
    required this.sourceRawText,
    required this.sourceFileName,
    required this.sourceFileType,
    required this.draftFormat,
    required this.essayMode,
    required this.draftJson,
    required this.source,
    required this.status,
    required this.sessionType,
    required this.difficulty,
    required this.taskCodes,
    required this.xpReward,
    required this.xpEarned,
    required this.questionCount,
    required this.scoreCorrect,
    required this.scoreTotal,
    required this.scorePercent,
    required this.latestResultPackageId,
    required this.questions,
    this.aiModel,
    this.createdAt,
    this.publishedAt,
    this.availableOnDate,
    this.availableOnDay,
    this.subject,
  });

  final String id;
  final String title;
  final String teacherNote;
  final String sourceUnitText;
  final String sourceRawText;
  final String sourceFileName;
  final String sourceFileType;
  final String draftFormat;
  final String essayMode;
  final Map<String, dynamic>? draftJson;
  final String source;
  final String status;
  final String sessionType;
  final String difficulty;
  final List<String> taskCodes;
  final int xpReward;
  final int xpEarned;
  final int questionCount;
  final int scoreCorrect;
  final int scoreTotal;
  final int scorePercent;
  final String latestResultPackageId;
  final String? aiModel;
  final String? createdAt;
  final String? publishedAt;
  final String? availableOnDate;
  final String? availableOnDay;
  final MissionSubject? subject;
  final List<MissionQuestion> questions;

  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  EssayBuilderDraft? get essayBuilderDraft {
    if (draftFormat != 'ESSAY_BUILDER') {
      return null;
    }
    final json = draftJson;
    if (json == null) {
      return null;
    }
    return EssayBuilderDraft.fromJson(json);
  }

  MissionPayload copyWith({
    String? id,
    String? title,
    String? teacherNote,
    String? sourceUnitText,
    String? sourceRawText,
    String? sourceFileName,
    String? sourceFileType,
    String? draftFormat,
    String? essayMode,
    Map<String, dynamic>? draftJson,
    String? source,
    String? status,
    String? sessionType,
    String? difficulty,
    List<String>? taskCodes,
    int? xpReward,
    int? xpEarned,
    int? questionCount,
    int? scoreCorrect,
    int? scoreTotal,
    int? scorePercent,
    String? latestResultPackageId,
    String? aiModel,
    String? createdAt,
    String? publishedAt,
    String? availableOnDate,
    String? availableOnDay,
    MissionSubject? subject,
    List<MissionQuestion>? questions,
  }) {
    return MissionPayload(
      id: id ?? this.id,
      title: title ?? this.title,
      teacherNote: teacherNote ?? this.teacherNote,
      sourceUnitText: sourceUnitText ?? this.sourceUnitText,
      sourceRawText: sourceRawText ?? this.sourceRawText,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      sourceFileType: sourceFileType ?? this.sourceFileType,
      draftFormat: draftFormat ?? this.draftFormat,
      essayMode: essayMode ?? this.essayMode,
      draftJson: draftJson ?? this.draftJson,
      source: source ?? this.source,
      status: status ?? this.status,
      sessionType: sessionType ?? this.sessionType,
      difficulty: difficulty ?? this.difficulty,
      taskCodes: taskCodes ?? this.taskCodes,
      xpReward: xpReward ?? this.xpReward,
      xpEarned: xpEarned ?? this.xpEarned,
      questionCount: questionCount ?? this.questionCount,
      scoreCorrect: scoreCorrect ?? this.scoreCorrect,
      scoreTotal: scoreTotal ?? this.scoreTotal,
      scorePercent: scorePercent ?? this.scorePercent,
      latestResultPackageId:
          latestResultPackageId ?? this.latestResultPackageId,
      aiModel: aiModel ?? this.aiModel,
      createdAt: createdAt ?? this.createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
      availableOnDate: availableOnDate ?? this.availableOnDate,
      availableOnDay: availableOnDay ?? this.availableOnDay,
      subject: subject ?? this.subject,
      questions: questions ?? this.questions,
    );
  }

  factory MissionPayload.fromJson(Map<String, dynamic> json) {
    return MissionPayload(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      teacherNote: (json['teacherNote'] ?? '').toString(),
      sourceUnitText: (json['sourceUnitText'] ?? '').toString(),
      sourceRawText: (json['sourceRawText'] ?? '').toString(),
      sourceFileName: (json['sourceFileName'] ?? '').toString(),
      sourceFileType: (json['sourceFileType'] ?? '').toString(),
      draftFormat: (json['draftFormat'] ?? 'QUESTIONS').toString(),
      essayMode: (json['essayMode'] ?? '').toString(),
      draftJson: _asNullableMap(json['draftJson']),
      source: (json['source'] ?? '').toString(),
      status: (json['status'] ?? 'published').toString(),
      sessionType: (json['sessionType'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? '').toString(),
      taskCodes: _asStringList(json['taskCodes']),
      xpReward: _asInt(json['xpReward']),
      xpEarned: _asInt(json['xpEarned']),
      questionCount: _asInt(json['questionCount']),
      scoreCorrect: _asInt(json['scoreCorrect']),
      scoreTotal: _asInt(json['scoreTotal']) > 0
          ? _asInt(json['scoreTotal'])
          : _asInt(json['questionCount']),
      scorePercent: _asInt(json['scorePercent']),
      latestResultPackageId: (json['latestResultPackageId'] ?? '').toString(),
      aiModel: json['aiModel']?.toString(),
      createdAt: json['createdAt']?.toString(),
      publishedAt: json['publishedAt']?.toString(),
      availableOnDate: json['availableOnDate']?.toString(),
      availableOnDay: json['availableOnDay']?.toString(),
      subject: _asNullableMap(json['subject']) == null
          ? null
          : MissionSubject.fromJson(_asMap(json['subject'])),
      questions: (json['questions'] as List<dynamic>? ?? const [])
          .map((item) => MissionQuestion.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class ResultHistoryItem {
  const ResultHistoryItem({
    required this.id,
    required this.resultPackageId,
    required this.resultKind,
    required this.missionId,
    required this.title,
    required this.teacherNote,
    required this.sourceUnitText,
    required this.sourceRawText,
    required this.sourceFileName,
    required this.sourceFileType,
    required this.draftFormat,
    required this.essayMode,
    required this.draftJson,
    required this.source,
    required this.status,
    required this.sessionType,
    required this.difficulty,
    required this.taskCodes,
    required this.xpReward,
    required this.xpEarned,
    required this.questionCount,
    required this.scoreCorrect,
    required this.scoreTotal,
    required this.scorePercent,
    required this.questions,
    required this.hasTeacherCopy,
    this.aiModel,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.availableOnDate,
    this.availableOnDay,
    this.subject,
  });

  final String id;
  final String resultPackageId;
  final String resultKind;
  final String missionId;
  final String title;
  final String teacherNote;
  final String sourceUnitText;
  final String sourceRawText;
  final String sourceFileName;
  final String sourceFileType;
  final String draftFormat;
  final String essayMode;
  final Map<String, dynamic>? draftJson;
  final String source;
  final String status;
  final String sessionType;
  final String difficulty;
  final List<String> taskCodes;
  final int xpReward;
  final int xpEarned;
  final int questionCount;
  final int scoreCorrect;
  final int scoreTotal;
  final int scorePercent;
  final String? aiModel;
  final String? createdAt;
  final String? updatedAt;
  final String? publishedAt;
  final String? availableOnDate;
  final String? availableOnDay;
  final MissionSubject? subject;
  final List<MissionQuestion> questions;
  final bool hasTeacherCopy;

  String get latestResultPackageId => resultPackageId;
  bool get isPaperAssessment => resultKind == 'paper_assessment';
  bool get isMissionBased => !isPaperAssessment;
  EssayBuilderDraft? get essayBuilderDraft {
    if (draftFormat != 'ESSAY_BUILDER') {
      return null;
    }
    final json = draftJson;
    if (json == null) {
      return null;
    }
    return EssayBuilderDraft.fromJson(json);
  }

  MissionPayload toMissionContext() {
    return MissionPayload(
      id: missionId,
      title: title,
      teacherNote: teacherNote,
      sourceUnitText: sourceUnitText,
      sourceRawText: sourceRawText,
      sourceFileName: sourceFileName,
      sourceFileType: sourceFileType,
      draftFormat: draftFormat,
      essayMode: essayMode,
      draftJson: draftJson,
      source: source,
      status: status,
      sessionType: sessionType,
      difficulty: difficulty,
      taskCodes: taskCodes,
      xpReward: xpReward,
      xpEarned: xpEarned,
      questionCount: questionCount,
      scoreCorrect: scoreCorrect,
      scoreTotal: scoreTotal,
      scorePercent: scorePercent,
      latestResultPackageId: resultPackageId,
      aiModel: aiModel,
      createdAt: createdAt,
      publishedAt: publishedAt,
      availableOnDate: availableOnDate,
      availableOnDay: availableOnDay,
      subject: subject,
      questions: questions,
    );
  }

  factory ResultHistoryItem.fromJson(Map<String, dynamic> json) {
    final resultPackageId =
        (json['resultPackageId'] ?? json['latestResultPackageId'] ?? '')
            .toString();
    final missionId = (json['missionId'] ?? json['id'] ?? '').toString();
    final normalizedResultKind =
        (json['resultKind'] ?? '').toString().trim().isNotEmpty
        ? (json['resultKind'] ?? '').toString().trim()
        : missionId.trim().isEmpty
        ? 'paper_assessment'
        : 'mission';
    final questionCount = _asInt(json['questionCount']);
    final parsedScoreTotal = _asInt(json['scoreTotal']);

    return ResultHistoryItem(
      id:
          (json['historyId'] ??
                  (resultPackageId.trim().isNotEmpty
                      ? resultPackageId
                      : missionId))
              .toString(),
      resultPackageId: resultPackageId,
      resultKind: normalizedResultKind,
      missionId: missionId,
      title: (json['title'] ?? '').toString(),
      teacherNote: (json['teacherNote'] ?? '').toString(),
      sourceUnitText: (json['sourceUnitText'] ?? '').toString(),
      sourceRawText: (json['sourceRawText'] ?? '').toString(),
      sourceFileName: (json['sourceFileName'] ?? '').toString(),
      sourceFileType: (json['sourceFileType'] ?? '').toString(),
      draftFormat: (json['draftFormat'] ?? 'QUESTIONS').toString(),
      essayMode: (json['essayMode'] ?? '').toString(),
      draftJson: _asNullableMap(json['draftJson']),
      source: (json['source'] ?? '').toString(),
      status:
          (json['status'] ??
                  (normalizedResultKind == 'paper_assessment'
                      ? 'paper_assessment'
                      : 'published'))
              .toString(),
      sessionType: (json['sessionType'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? '').toString(),
      taskCodes: _asStringList(json['taskCodes']),
      xpReward: _asInt(json['xpReward']) > 0
          ? _asInt(json['xpReward'])
          : normalizedResultKind == 'paper_assessment'
          ? 30
          : 0,
      xpEarned: _asInt(json['xpEarned']),
      questionCount: questionCount,
      scoreCorrect: _asInt(json['scoreCorrect']),
      scoreTotal: parsedScoreTotal > 0 ? parsedScoreTotal : questionCount,
      scorePercent: _asInt(json['scorePercent']),
      aiModel: json['aiModel']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      publishedAt: json['publishedAt']?.toString(),
      availableOnDate: json['availableOnDate']?.toString(),
      availableOnDay: json['availableOnDay']?.toString(),
      subject: _asNullableMap(json['subject']) == null
          ? null
          : MissionSubject.fromJson(_asMap(json['subject'])),
      questions: (json['questions'] as List<dynamic>? ?? const [])
          .map((item) => MissionQuestion.fromJson(_asMap(item)))
          .toList(growable: false),
      hasTeacherCopy: json['hasTeacherCopy'] == false
          ? false
          : normalizedResultKind == 'mission' && missionId.trim().isNotEmpty,
    );
  }
}

class EssayBuilderDraft {
  const EssayBuilderDraft({
    required this.type,
    required this.mode,
    required this.targets,
    required this.sentences,
  });

  final String type;
  final String mode;
  final EssayBuilderTargets targets;
  final List<EssayBuilderSentence> sentences;

  factory EssayBuilderDraft.fromJson(Map<String, dynamic> json) {
    return EssayBuilderDraft(
      type: (json['type'] ?? '').toString(),
      mode: (json['mode'] ?? '').toString(),
      targets: EssayBuilderTargets.fromJson(_asMap(json['targets'])),
      sentences: (json['sentences'] as List<dynamic>? ?? const [])
          .map((item) => EssayBuilderSentence.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class EssayBuilderTargets {
  const EssayBuilderTargets({
    required this.targetWordMin,
    required this.targetWordMax,
    required this.targetSentenceCount,
    required this.targetBlankCount,
  });

  final int targetWordMin;
  final int targetWordMax;
  final int targetSentenceCount;
  final int targetBlankCount;

  factory EssayBuilderTargets.fromJson(Map<String, dynamic> json) {
    return EssayBuilderTargets(
      targetWordMin: _asInt(json['targetWordMin']),
      targetWordMax: _asInt(json['targetWordMax']),
      targetSentenceCount: _asInt(json['targetSentenceCount']),
      targetBlankCount: _asInt(json['targetBlankCount']),
    );
  }
}

class EssaySentenceLearnFirst {
  const EssaySentenceLearnFirst({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  factory EssaySentenceLearnFirst.fromJson(Map<String, dynamic> json) {
    return EssaySentenceLearnFirst(
      title: (json['title'] ?? '').toString(),
      bullets: _asStringList(json['bullets']),
    );
  }
}

class EssayBuilderSentence {
  const EssayBuilderSentence({
    required this.id,
    required this.role,
    required this.learnFirst,
    required this.parts,
  });

  final String id;
  final String role;
  final EssaySentenceLearnFirst learnFirst;
  final List<EssayBuilderPart> parts;

  factory EssayBuilderSentence.fromJson(Map<String, dynamic> json) {
    return EssayBuilderSentence(
      id: (json['id'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      learnFirst: EssaySentenceLearnFirst.fromJson(_asMap(json['learnFirst'])),
      parts: (json['parts'] as List<dynamic>? ?? const [])
          .map((item) => EssayBuilderPart.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class EssayBuilderPart {
  const EssayBuilderPart({
    required this.type,
    required this.value,
    required this.blankId,
    required this.hint,
    required this.options,
    required this.correctOption,
  });

  final String type;
  final String value;
  final String blankId;
  final String hint;
  final Map<String, String> options;
  final String correctOption;

  bool get isBlank => type == 'blank';

  factory EssayBuilderPart.fromJson(Map<String, dynamic> json) {
    final options = _asNullableMap(json['options']);
    final normalizedCorrectOption = (json['correctOption'] ?? 'A')
        .toString()
        .trim()
        .toUpperCase();
    final correctOption =
        const ['A', 'B', 'C', 'D'].contains(normalizedCorrectOption)
        ? normalizedCorrectOption
        : 'A';
    return EssayBuilderPart(
      type: (json['type'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      blankId: (json['blankId'] ?? '').toString(),
      hint: (json['hint'] ?? '').toString(),
      options: options == null
          ? const {}
          : options.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
      correctOption: correctOption,
    );
  }
}

class UploadedUnitPlanDraft {
  const UploadedUnitPlanDraft({
    required this.unitTitle,
    required this.unitSummary,
    required this.keyPoints,
    required this.suggestedMissionTitle,
    required this.suggestedTeacherNote,
    required this.suggestedQuestionCount,
    required this.suggestedXpReward,
    this.aiModel,
  });

  final String unitTitle;
  final String unitSummary;
  final List<String> keyPoints;
  final String suggestedMissionTitle;
  final String suggestedTeacherNote;
  final int suggestedQuestionCount;
  final int suggestedXpReward;
  final String? aiModel;

  factory UploadedUnitPlanDraft.fromJson(Map<String, dynamic> json) {
    return UploadedUnitPlanDraft(
      unitTitle: (json['unitTitle'] ?? '').toString(),
      unitSummary: (json['unitSummary'] ?? '').toString(),
      keyPoints: _asStringList(json['keyPoints']),
      suggestedMissionTitle: (json['suggestedMissionTitle'] ?? '').toString(),
      suggestedTeacherNote: (json['suggestedTeacherNote'] ?? '').toString(),
      suggestedQuestionCount: _asInt(json['suggestedQuestionCount']),
      suggestedXpReward: _asInt(json['suggestedXpReward']),
      aiModel: json['aiModel']?.toString(),
    );
  }
}

class MissionSourceReadiness {
  const MissionSourceReadiness({
    required this.status,
    required this.summary,
    required this.detectedSignals,
    required this.missingRequirements,
    required this.warningNotes,
  });

  final String status;
  final String summary;
  final List<String> detectedSignals;
  final List<String> missingRequirements;
  final List<String> warningNotes;

  bool get isReady => status == 'ready';
  bool get needsAttention => status == 'needs_attention';

  factory MissionSourceReadiness.fromJson(Map<String, dynamic> json) {
    return MissionSourceReadiness(
      status: (json['status'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      detectedSignals: _asStringList(json['detectedSignals']),
      missingRequirements: _asStringList(json['missingRequirements']),
      warningNotes: _asStringList(json['warningNotes']),
    );
  }
}

class UploadedSourceDraft {
  const UploadedSourceDraft({
    required this.fileName,
    required this.mimeType,
    required this.sourceKind,
    required this.extractedText,
    required this.extractedCharacterCount,
    required this.unitPlan,
    required this.draftReadiness,
    this.prefilledMission,
  });

  final String fileName;
  final String mimeType;
  final String sourceKind;
  final String extractedText;
  final int extractedCharacterCount;
  final UploadedUnitPlanDraft unitPlan;
  final MissionSourceReadiness draftReadiness;
  final MissionPayload? prefilledMission;

  factory UploadedSourceDraft.fromJson(Map<String, dynamic> json) {
    return UploadedSourceDraft(
      fileName: (json['fileName'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      sourceKind: (json['sourceKind'] ?? '').toString(),
      extractedText: (json['extractedText'] ?? '').toString(),
      extractedCharacterCount: _asInt(json['extractedCharacterCount']),
      unitPlan: UploadedUnitPlanDraft.fromJson(_asMap(json['unitPlan'])),
      draftReadiness: MissionSourceReadiness.fromJson(
        _asMap(json['draftReadiness']),
      ),
      prefilledMission: _asNullableMap(json['prefilledMission']) == null
          ? null
          : MissionPayload.fromJson(_asMap(json['prefilledMission'])),
    );
  }
}

class CriterionDraftSummary {
  const CriterionDraftSummary({required this.id, required this.title});

  final String id;
  final String title;

  factory CriterionDraftSummary.fromJson(Map<String, dynamic> json) {
    return CriterionDraftSummary(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
    );
  }
}

class CriterionDraftLearningContent {
  const CriterionDraftLearningContent({
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String title;
  final String summary;
  final List<LearningSection> sections;

  factory CriterionDraftLearningContent.fromJson(Map<String, dynamic> json) {
    return CriterionDraftLearningContent(
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .map((item) => LearningSection.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class CriterionAiDraft {
  const CriterionAiDraft({
    required this.criterion,
    required this.subject,
    required this.unit,
    required this.source,
    required this.learningContent,
    required this.learningCheckBlocks,
    required this.essayBuilderBlocks,
    this.aiModel,
  });

  final CriterionDraftSummary criterion;
  final SubjectSummary? subject;
  final CriterionUnit? unit;
  final String source;
  final String? aiModel;
  final CriterionDraftLearningContent learningContent;
  final List<CriterionBlock> learningCheckBlocks;
  final List<CriterionBlock> essayBuilderBlocks;

  factory CriterionAiDraft.fromJson(Map<String, dynamic> json) {
    return CriterionAiDraft(
      criterion: CriterionDraftSummary.fromJson(_asMap(json['criterion'])),
      subject: _asNullableMap(json['subject']) == null
          ? null
          : SubjectSummary.fromJson(_asMap(json['subject'])),
      unit: _asNullableMap(json['unit']) == null
          ? null
          : CriterionUnit.fromJson(_asMap(json['unit'])),
      source: (json['source'] ?? '').toString(),
      aiModel: json['aiModel']?.toString(),
      learningContent: CriterionDraftLearningContent.fromJson(
        _asMap(json['learningContent']),
      ),
      learningCheckBlocks:
          (json['learningCheckBlocks'] as List<dynamic>? ?? const [])
              .map((item) => CriterionBlock.fromJson(_asMap(item)))
              .toList(growable: false),
      essayBuilderBlocks:
          (json['essayBuilderBlocks'] as List<dynamic>? ?? const [])
              .map((item) => CriterionBlock.fromJson(_asMap(item)))
              .toList(growable: false),
    );
  }
}

class UploadedCriterionSourceDraft {
  const UploadedCriterionSourceDraft({
    required this.fileName,
    required this.mimeType,
    required this.sourceKind,
    required this.extractedText,
    required this.extractedCharacterCount,
    required this.criterion,
    required this.subject,
    required this.unit,
    required this.unitPlan,
  });

  final String fileName;
  final String mimeType;
  final String sourceKind;
  final String extractedText;
  final int extractedCharacterCount;
  final CriterionDraftSummary criterion;
  final SubjectSummary? subject;
  final CriterionUnit? unit;
  final UploadedUnitPlanDraft unitPlan;

  factory UploadedCriterionSourceDraft.fromJson(Map<String, dynamic> json) {
    return UploadedCriterionSourceDraft(
      fileName: (json['fileName'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      sourceKind: (json['sourceKind'] ?? '').toString(),
      extractedText: (json['extractedText'] ?? '').toString(),
      extractedCharacterCount: _asInt(json['extractedCharacterCount']),
      criterion: CriterionDraftSummary.fromJson(_asMap(json['criterion'])),
      subject: _asNullableMap(json['subject']) == null
          ? null
          : SubjectSummary.fromJson(_asMap(json['subject'])),
      unit: _asNullableMap(json['unit']) == null
          ? null
          : CriterionUnit.fromJson(_asMap(json['unit'])),
      unitPlan: UploadedUnitPlanDraft.fromJson(_asMap(json['unitPlan'])),
    );
  }
}

class StartedMission {
  const StartedMission({
    required this.startedAt,
    required this.studentId,
    required this.subjectId,
    required this.sessionType,
    required this.maxQuestions,
    required this.mission,
  });

  final String startedAt;
  final String studentId;
  final String subjectId;
  final String sessionType;
  final int maxQuestions;
  final MissionPayload mission;

  factory StartedMission.fromJson(Map<String, dynamic> json) {
    return StartedMission(
      startedAt: (json['startedAt'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      subjectId: (json['subjectId'] ?? '').toString(),
      sessionType: (json['sessionType'] ?? '').toString(),
      maxQuestions: _asInt(json['maxQuestions']),
      mission: MissionPayload.fromJson(_asMap(json['mission'])),
    );
  }
}

class StandalonePaperSessionResponse {
  const StandalonePaperSessionResponse({
    required this.itemIndex,
    required this.itemType,
    required this.selectedOptionIndex,
    required this.textAnswer,
    required this.flagged,
    required this.answeredAt,
    required this.teacherScorePercent,
    required this.teacherFeedback,
  });

  final int itemIndex;
  final String itemType;
  final int selectedOptionIndex;
  final String textAnswer;
  final bool flagged;
  final String? answeredAt;
  final int? teacherScorePercent;
  final String teacherFeedback;

  factory StandalonePaperSessionResponse.fromJson(Map<String, dynamic> json) {
    return StandalonePaperSessionResponse(
      itemIndex: _asInt(json['itemIndex']),
      itemType: (json['itemType'] ?? '').toString(),
      selectedOptionIndex: _asNullableInt(json['selectedOptionIndex']) ?? -1,
      textAnswer: (json['textAnswer'] ?? '').toString(),
      flagged: json['flagged'] == true,
      answeredAt: json['answeredAt']?.toString(),
      teacherScorePercent: _asNullableInt(json['teacherScorePercent']),
      teacherFeedback: (json['teacherFeedback'] ?? '').toString(),
    );
  }
}

class StandalonePaperIntegrityEvent {
  const StandalonePaperIntegrityEvent({
    required this.eventType,
    required this.detail,
    required this.actionTaken,
    required this.occurredAt,
    required this.warningCountAfter,
    required this.leaveCountAfter,
  });

  final String eventType;
  final String detail;
  final String actionTaken;
  final String? occurredAt;
  final int warningCountAfter;
  final int leaveCountAfter;

  factory StandalonePaperIntegrityEvent.fromJson(Map<String, dynamic> json) {
    return StandalonePaperIntegrityEvent(
      eventType: (json['eventType'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      actionTaken: (json['actionTaken'] ?? '').toString(),
      occurredAt: json['occurredAt']?.toString(),
      warningCountAfter: _asInt(json['warningCountAfter']),
      leaveCountAfter: _asInt(json['leaveCountAfter']),
    );
  }
}

class StandalonePaperSessionState {
  const StandalonePaperSessionState({
    required this.id,
    required this.paperId,
    required this.status,
    required this.attemptNumber,
    required this.startedAt,
    required this.endsAt,
    required this.submittedAt,
    required this.lockedAt,
    required this.resetAt,
    required this.lastHeartbeatAt,
    required this.currentItemIndex,
    required this.warningCount,
    required this.leaveCount,
    required this.totalItems,
    required this.answeredCount,
    required this.autoScorePercent,
    required this.reviewStatus,
    required this.submittedReason,
    required this.resultPackageId,
    required this.sessionLogId,
    required this.secondsRemaining,
    required this.integrityEvents,
    required this.responses,
  });

  final String id;
  final String paperId;
  final String status;
  final int attemptNumber;
  final String? startedAt;
  final String? endsAt;
  final String? submittedAt;
  final String? lockedAt;
  final String? resetAt;
  final String? lastHeartbeatAt;
  final int currentItemIndex;
  final int warningCount;
  final int leaveCount;
  final int totalItems;
  final int answeredCount;
  final int autoScorePercent;
  final String reviewStatus;
  final String submittedReason;
  final String resultPackageId;
  final String sessionLogId;
  final int? secondsRemaining;
  final List<StandalonePaperIntegrityEvent> integrityEvents;
  final List<StandalonePaperSessionResponse> responses;

  bool get isActive => status == 'active';
  bool get isLocked => status == 'locked';
  bool get isSubmitted => status == 'submitted' || status == 'time_expired';
  bool get isPendingReview => reviewStatus == 'pending_review';

  factory StandalonePaperSessionState.fromJson(Map<String, dynamic> json) {
    return StandalonePaperSessionState(
      id: (json['id'] ?? '').toString(),
      paperId: (json['paperId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      attemptNumber: _asNullableInt(json['attemptNumber']) ?? 1,
      startedAt: json['startedAt']?.toString(),
      endsAt: json['endsAt']?.toString(),
      submittedAt: json['submittedAt']?.toString(),
      lockedAt: json['lockedAt']?.toString(),
      resetAt: json['resetAt']?.toString(),
      lastHeartbeatAt: json['lastHeartbeatAt']?.toString(),
      currentItemIndex: _asInt(json['currentItemIndex']),
      warningCount: _asInt(json['warningCount']),
      leaveCount: _asInt(json['leaveCount']),
      totalItems: _asInt(json['totalItems']),
      answeredCount: _asInt(json['answeredCount']),
      autoScorePercent: _asInt(json['autoScorePercent']),
      reviewStatus: (json['reviewStatus'] ?? '').toString(),
      submittedReason: (json['submittedReason'] ?? '').toString(),
      resultPackageId: (json['resultPackageId'] ?? '').toString(),
      sessionLogId: (json['sessionLogId'] ?? '').toString(),
      secondsRemaining: _asNullableInt(json['secondsRemaining']),
      integrityEvents: (json['integrityEvents'] as List<dynamic>? ?? const [])
          .map((item) => StandalonePaperIntegrityEvent.fromJson(_asMap(item)))
          .toList(growable: false),
      responses: (json['responses'] as List<dynamic>? ?? const [])
          .map((item) => StandalonePaperSessionResponse.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class StandalonePaperPlayerItem {
  const StandalonePaperPlayerItem({
    required this.itemIndex,
    required this.itemType,
    required this.learningText,
    required this.prompt,
    required this.options,
    required this.minWordCount,
  });

  final int itemIndex;
  final String itemType;
  final String learningText;
  final String prompt;
  final List<String> options;
  final int minWordCount;

  factory StandalonePaperPlayerItem.fromJson(Map<String, dynamic> json) {
    return StandalonePaperPlayerItem(
      itemIndex: _asInt(json['itemIndex']),
      itemType: (json['itemType'] ?? '').toString(),
      learningText: (json['learningText'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      options: _asStringList(json['options']),
      minWordCount: _asInt(json['minWordCount']),
    );
  }
}

class StandalonePaperPlayerPaper {
  const StandalonePaperPlayerPaper({
    required this.id,
    required this.paperKind,
    required this.sessionType,
    required this.title,
    required this.teacherNote,
    required this.sourceUnitText,
    required this.targetDate,
    required this.durationMinutes,
    required this.subject,
    required this.items,
  });

  final String id;
  final String paperKind;
  final String sessionType;
  final String title;
  final String teacherNote;
  final String sourceUnitText;
  final String targetDate;
  final int durationMinutes;
  final MissionSubject? subject;
  final List<StandalonePaperPlayerItem> items;

  bool get isExam => paperKind.trim().toUpperCase() == 'EXAM';

  factory StandalonePaperPlayerPaper.fromJson(Map<String, dynamic> json) {
    return StandalonePaperPlayerPaper(
      id: (json['id'] ?? '').toString(),
      paperKind: (json['paperKind'] ?? '').toString(),
      sessionType: (json['sessionType'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      teacherNote: (json['teacherNote'] ?? '').toString(),
      sourceUnitText: (json['sourceUnitText'] ?? '').toString(),
      targetDate: (json['targetDate'] ?? '').toString(),
      durationMinutes: _asInt(json['durationMinutes']),
      subject: _asNullableMap(json['subject']) == null
          ? null
          : MissionSubject.fromJson(_asMap(json['subject'])),
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((item) => StandalonePaperPlayerItem.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class StartedStandalonePaperSession {
  const StartedStandalonePaperSession({
    required this.paper,
    required this.session,
    this.message = '',
  });

  final StandalonePaperPlayerPaper paper;
  final StandalonePaperSessionState session;
  final String message;

  factory StartedStandalonePaperSession.fromJson(Map<String, dynamic> json) {
    return StartedStandalonePaperSession(
      paper: StandalonePaperPlayerPaper.fromJson(_asMap(json['paper'])),
      session: StandalonePaperSessionState.fromJson(_asMap(json['session'])),
      message: (json['message'] ?? '').toString(),
    );
  }
}

class StandalonePaperAvailability {
  const StandalonePaperAvailability({
    required this.id,
    required this.paperKind,
    required this.sessionType,
    required this.title,
    required this.teacherNote,
    required this.targetDate,
    required this.durationMinutes,
    required this.status,
    required this.subject,
    required this.latestSession,
  });

  final String id;
  final String paperKind;
  final String sessionType;
  final String title;
  final String teacherNote;
  final String targetDate;
  final int durationMinutes;
  final String status;
  final MissionSubject? subject;
  final StandalonePaperSessionState? latestSession;

  bool get isExam => paperKind.trim().toUpperCase() == 'EXAM';

  factory StandalonePaperAvailability.fromJson(Map<String, dynamic> json) {
    return StandalonePaperAvailability(
      id: (json['id'] ?? '').toString(),
      paperKind: (json['paperKind'] ?? '').toString(),
      sessionType: (json['sessionType'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      teacherNote: (json['teacherNote'] ?? '').toString(),
      targetDate: (json['targetDate'] ?? '').toString(),
      durationMinutes: _asInt(json['durationMinutes']),
      status: (json['status'] ?? '').toString(),
      subject: _asNullableMap(json['subject']) == null
          ? null
          : MissionSubject.fromJson(_asMap(json['subject'])),
      latestSession: _asNullableMap(json['latestSession']) == null
          ? null
          : StandalonePaperSessionState.fromJson(_asMap(json['latestSession'])),
    );
  }
}

class CompleteMissionResult {
  const CompleteMissionResult({
    required this.student,
    required this.subjectCompletionBonusXp,
    required this.dailyXp,
    required this.resultPackageId,
    this.sessionXpAwarded = 0,
    this.theoryReviewStatus = '',
    this.theoryXpPending = false,
  });

  final AppUser student;
  final int subjectCompletionBonusXp;
  final DailyXpSummary dailyXp;
  final String resultPackageId;
  final int sessionXpAwarded;
  final String theoryReviewStatus;
  final bool theoryXpPending;

  factory CompleteMissionResult.fromJson(Map<String, dynamic> json) {
    final dailyXpJson = _asMap(json['dailyXp']);
    final sessionLog = _asMap(json['sessionLog']);
    return CompleteMissionResult(
      student: AppUser.fromJson(_asMap(json['student'])),
      subjectCompletionBonusXp: _asInt(dailyXpJson['subjectCompletionBonusXp']),
      dailyXp: DailyXpSummary.fromJson(dailyXpJson),
      resultPackageId: (json['resultPackageId'] ?? '').toString(),
      sessionXpAwarded: _asInt(
        sessionLog['totalXpAwarded'] ?? sessionLog['xpAwarded'],
      ),
      theoryReviewStatus: (json['theoryReviewStatus'] ?? '').toString(),
      theoryXpPending: json['theoryXpPending'] == true,
    );
  }
}

class ResultPackageMeta {
  const ResultPackageMeta({
    required this.studentName,
    required this.studentId,
    required this.teacherId,
    required this.missionId,
    required this.missionTitle,
    required this.subject,
    required this.taskCodes,
    required this.assignedDate,
    required this.startTime,
    required this.submitTime,
    required this.durationSeconds,
    required this.scoreCorrect,
    required this.scoreTotal,
    required this.scorePercent,
    required this.xpAwarded,
  });

  final String studentName;
  final String studentId;
  final String teacherId;
  final String missionId;
  final String missionTitle;
  final String subject;
  final List<String> taskCodes;
  final String assignedDate;
  final String? startTime;
  final String? submitTime;
  final int durationSeconds;
  final int scoreCorrect;
  final int scoreTotal;
  final int scorePercent;
  final int xpAwarded;

  factory ResultPackageMeta.fromJson(Map<String, dynamic> json) {
    final score = _asMap(json['score']);
    return ResultPackageMeta(
      studentName: (json['studentName'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      teacherId: (json['teacherId'] ?? '').toString(),
      missionId: (json['missionId'] ?? '').toString(),
      missionTitle: (json['missionTitle'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      taskCodes: _asStringList(json['taskCodes']),
      assignedDate: (json['assignedDate'] ?? '').toString(),
      startTime: json['startTime']?.toString(),
      submitTime: json['submitTime']?.toString(),
      durationSeconds: _asInt(json['durationSeconds']),
      scoreCorrect: _asInt(score['correct']),
      scoreTotal: _asInt(score['total']),
      scorePercent: _asInt(score['percent']),
      xpAwarded: _asInt(json['xpAwarded']),
    );
  }
}

class ResultSendChannelStatus {
  const ResultSendChannelStatus({
    required this.status,
    required this.failureReason,
  });

  final String status;
  final String failureReason;

  factory ResultSendChannelStatus.fromJson(Map<String, dynamic> json) {
    return ResultSendChannelStatus(
      status: (json['status'] ?? 'not_requested').toString(),
      failureReason: (json['failureReason'] ?? '').toString(),
    );
  }
}

class ResultSendChannelAttempt {
  const ResultSendChannelAttempt({required this.inApp, required this.email});

  final bool inApp;
  final bool email;

  factory ResultSendChannelAttempt.fromJson(Map<String, dynamic> json) {
    return ResultSendChannelAttempt(
      inApp: json['inApp'] == true,
      email: json['email'] == true,
    );
  }
}

class ResultSendRetryStatus {
  const ResultSendRetryStatus({
    required this.pending,
    required this.retryCount,
    required this.maxRetries,
    required this.nextRetryAt,
    required this.lastAttemptAt,
  });

  final bool pending;
  final int retryCount;
  final int maxRetries;
  final String? nextRetryAt;
  final String? lastAttemptAt;

  factory ResultSendRetryStatus.fromJson(Map<String, dynamic> json) {
    return ResultSendRetryStatus(
      pending: json['pending'] == true,
      retryCount: _asInt(json['retryCount']),
      maxRetries: _asInt(json['maxRetries']),
      nextRetryAt: json['nextRetryAt']?.toString(),
      lastAttemptAt: json['lastAttemptAt']?.toString(),
    );
  }
}

class ResultSendLog {
  const ResultSendLog({
    required this.id,
    required this.resultPackageId,
    required this.sentBy,
    required this.sentAt,
    required this.recipients,
    required this.channelsAttempted,
    required this.inAppStatus,
    required this.emailStatus,
    required this.failureReason,
    required this.screenshotUrl,
    required this.emailRetry,
  });

  final String id;
  final String resultPackageId;
  final String sentBy;
  final String? sentAt;
  final List<String> recipients;
  final ResultSendChannelAttempt channelsAttempted;
  final ResultSendChannelStatus inAppStatus;
  final ResultSendChannelStatus emailStatus;
  final String failureReason;
  final String screenshotUrl;
  final ResultSendRetryStatus emailRetry;

  factory ResultSendLog.fromJson(Map<String, dynamic> json) {
    final channelStatus = _asMap(json['channelStatus']);
    return ResultSendLog(
      id: (json['id'] ?? '').toString(),
      resultPackageId: (json['resultPackageId'] ?? '').toString(),
      sentBy: (json['sentBy'] ?? '').toString(),
      sentAt: json['sentAt']?.toString(),
      recipients: _asStringList(json['recipients']),
      channelsAttempted: ResultSendChannelAttempt.fromJson(
        _asMap(json['channelsAttempted']),
      ),
      inAppStatus: ResultSendChannelStatus.fromJson(
        _asMap(channelStatus['inApp']),
      ),
      emailStatus: ResultSendChannelStatus.fromJson(
        _asMap(channelStatus['email']),
      ),
      failureReason: (json['failureReason'] ?? '').toString(),
      screenshotUrl: (json['screenshotUrl'] ?? '').toString(),
      emailRetry: ResultSendRetryStatus.fromJson(_asMap(json['emailRetry'])),
    );
  }
}

class ResultPackageData {
  const ResultPackageData({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.resultKind,
    required this.missionId,
    required this.missionType,
    required this.meta,
    required this.evidence,
    required this.latestSendStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.certification,
    required this.sendLogs,
  });

  final String id;
  final String studentId;
  final String teacherId;
  final String resultKind;
  final String missionId;
  final String missionType;
  final ResultPackageMeta meta;
  final Map<String, dynamic> evidence;
  final String latestSendStatus;
  final String? createdAt;
  final String? updatedAt;
  final MissionCertificationSummary? certification;
  final List<ResultSendLog> sendLogs;

  factory ResultPackageData.fromJson(Map<String, dynamic> json) {
    return ResultPackageData(
      id: (json['id'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      teacherId: (json['teacherId'] ?? '').toString(),
      resultKind: (json['resultKind'] ?? 'mission').toString(),
      missionId: (json['missionId'] ?? '').toString(),
      missionType: (json['missionType'] ?? '').toString(),
      meta: ResultPackageMeta.fromJson(_asMap(json['meta'])),
      evidence: _asMap(json['evidence']),
      latestSendStatus: (json['latestSendStatus'] ?? 'not_sent').toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      certification: _asNullableMap(json['certification']) == null
          ? null
          : MissionCertificationSummary.fromJson(_asMap(json['certification'])),
      sendLogs: (json['sendLogs'] as List<dynamic>? ?? const [])
          .map((item) => ResultSendLog.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class MissionCertificationSummary {
  const MissionCertificationSummary({
    required this.certificationEnabled,
    required this.certificationLabel,
    required this.requiredTaskCodes,
    required this.certificationEligible,
    required this.certificationTaskCode,
    required this.certificationCounted,
    required this.certificationPassStatus,
    required this.reason,
    required this.scorePercent,
  });

  final bool certificationEnabled;
  final String certificationLabel;
  final List<String> requiredTaskCodes;
  final bool certificationEligible;
  final String certificationTaskCode;
  final bool certificationCounted;
  final String certificationPassStatus;
  final String reason;
  final double scorePercent;

  factory MissionCertificationSummary.fromJson(Map<String, dynamic> json) {
    return MissionCertificationSummary(
      certificationEnabled: json['certificationEnabled'] == true,
      certificationLabel: (json['certificationLabel'] ?? '').toString(),
      requiredTaskCodes: _asStringList(json['requiredTaskCodes']),
      certificationEligible: json['certificationEligible'] == true,
      certificationTaskCode: (json['certificationTaskCode'] ?? '').toString(),
      certificationCounted: json['certificationCounted'] == true,
      certificationPassStatus:
          (json['certificationPassStatus'] ?? 'not_eligible').toString(),
      reason: (json['reason'] ?? '').toString(),
      scorePercent: _asDouble(json['scorePercent']),
    );
  }
}

class ResultScreenshotUploadData {
  const ResultScreenshotUploadData({
    required this.id,
    required this.resultPackageId,
    required this.screenshotUrl,
    required this.fileName,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.byteSize,
    required this.mimeType,
  });

  final String id;
  final String resultPackageId;
  final String screenshotUrl;
  final String fileName;
  final String uploadedBy;
  final String uploadedAt;
  final int byteSize;
  final String mimeType;

  factory ResultScreenshotUploadData.fromJson(Map<String, dynamic> json) {
    return ResultScreenshotUploadData(
      id: (json['id'] ?? '').toString(),
      resultPackageId: (json['resultPackageId'] ?? '').toString(),
      screenshotUrl: (json['screenshotUrl'] ?? '').toString(),
      fileName: (json['fileName'] ?? '').toString(),
      uploadedBy: (json['uploadedBy'] ?? '').toString(),
      uploadedAt: (json['uploadedAt'] ?? '').toString(),
      byteSize: _asInt(json['byteSize']),
      mimeType: (json['mimeType'] ?? '').toString(),
    );
  }
}

class MentorMetrics {
  const MentorMetrics({
    required this.averageFocusScore,
    required this.weeklyXp,
    required this.completedMissions,
  });

  final int averageFocusScore;
  final int weeklyXp;
  final int completedMissions;

  factory MentorMetrics.fromJson(Map<String, dynamic> json) {
    return MentorMetrics(
      averageFocusScore: _asInt(json['averageFocusScore']),
      weeklyXp: _asInt(json['weeklyXp']),
      completedMissions: _asInt(json['completedMissions']),
    );
  }
}

class TargetSummary {
  const TargetSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.difficulty,
    required this.targetType,
    required this.stars,
    required this.xpAwarded,
    required this.weekKey,
    required this.awardDateKey,
    this.createdByName = '',
    this.createdByRole = '',
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final String difficulty;
  final String targetType;
  final int stars;
  final int xpAwarded;
  final String weekKey;
  final String awardDateKey;
  final String createdByName;
  final String createdByRole;

  bool get isFixedTarget =>
      targetType == 'fixed_daily_mission' || targetType == 'fixed_assessment';

  TargetSummary copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    String? difficulty,
    String? targetType,
    int? stars,
    int? xpAwarded,
    String? weekKey,
    String? awardDateKey,
    String? createdByName,
    String? createdByRole,
  }) {
    return TargetSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      difficulty: difficulty ?? this.difficulty,
      targetType: targetType ?? this.targetType,
      stars: stars ?? this.stars,
      xpAwarded: xpAwarded ?? this.xpAwarded,
      weekKey: weekKey ?? this.weekKey,
      awardDateKey: awardDateKey ?? this.awardDateKey,
      createdByName: createdByName ?? this.createdByName,
      createdByRole: createdByRole ?? this.createdByRole,
    );
  }

  factory TargetSummary.fromJson(Map<String, dynamic> json) {
    return TargetSummary(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? '').toString(),
      targetType: (json['targetType'] ?? 'custom').toString(),
      stars: _asInt(json['stars']),
      xpAwarded: _asInt(json['xpAwarded']),
      weekKey: (json['weekKey'] ?? '').toString(),
      awardDateKey: (json['awardDateKey'] ?? '').toString(),
      createdByName: (json['createdByName'] ?? '').toString(),
      createdByRole: (json['createdByRole'] ?? '').toString(),
    );
  }
}

class ManagementTargetSessionComment {
  const ManagementTargetSessionComment({
    required this.id,
    required this.dateKey,
    required this.sessionType,
    required this.subjectName,
    required this.comment,
    this.teacherName = '',
    this.teacherRole = '',
    this.authorName = '',
    this.authorRole = '',
    this.plannedTeacherName = '',
    this.plannedTeacherRole = '',
    this.conductedByName = '',
    this.conductedByRole = '',
  });

  final String id;
  final String dateKey;
  final String sessionType;
  final String subjectName;
  final String comment;
  final String teacherName;
  final String teacherRole;
  final String authorName;
  final String authorRole;
  final String plannedTeacherName;
  final String plannedTeacherRole;
  final String conductedByName;
  final String conductedByRole;

  factory ManagementTargetSessionComment.fromJson(Map<String, dynamic> json) {
    return ManagementTargetSessionComment(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      dateKey: (json['dateKey'] ?? '').toString(),
      sessionType: (json['sessionType'] ?? '').toString(),
      subjectName: (json['subjectName'] ?? '').toString(),
      comment: (json['comment'] ?? '').toString(),
      teacherName: (json['teacherName'] ?? '').toString(),
      teacherRole: (json['teacherRole'] ?? '').toString(),
      authorName: (json['authorName'] ?? '').toString(),
      authorRole: (json['authorRole'] ?? '').toString(),
      plannedTeacherName: (json['plannedTeacherName'] ?? '').toString(),
      plannedTeacherRole: (json['plannedTeacherRole'] ?? '').toString(),
      conductedByName: (json['conductedByName'] ?? '').toString(),
      conductedByRole: (json['conductedByRole'] ?? '').toString(),
    );
  }
}

class ManagementTargetDateSection {
  const ManagementTargetDateSection({
    required this.dateKey,
    required this.targets,
    required this.sessionComments,
  });

  final String dateKey;
  final List<TargetSummary> targets;
  final List<ManagementTargetSessionComment> sessionComments;

  factory ManagementTargetDateSection.fromJson(Map<String, dynamic> json) {
    return ManagementTargetDateSection(
      dateKey: (json['dateKey'] ?? '').toString(),
      targets: (json['targets'] as List<dynamic>? ?? const [])
          .map((item) => TargetSummary.fromJson(_asMap(item)))
          .toList(growable: false),
      sessionComments: (json['sessionComments'] as List<dynamic>? ?? const [])
          .map((item) => ManagementTargetSessionComment.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class ManagementTargetHistory {
  const ManagementTargetHistory({
    required this.displayDateKeys,
    required this.targets,
    required this.sessionComments,
    required this.dateSections,
  });

  final List<String> displayDateKeys;
  final List<TargetSummary> targets;
  final List<ManagementTargetSessionComment> sessionComments;
  final List<ManagementTargetDateSection> dateSections;

  factory ManagementTargetHistory.fromJson(Map<String, dynamic> json) {
    return ManagementTargetHistory(
      displayDateKeys: _asStringList(json['displayDateKeys']),
      targets: (json['targets'] as List<dynamic>? ?? const [])
          .map((item) => TargetSummary.fromJson(_asMap(item)))
          .toList(growable: false),
      sessionComments: (json['sessionComments'] as List<dynamic>? ?? const [])
          .map((item) => ManagementTargetSessionComment.fromJson(_asMap(item)))
          .toList(growable: false),
      dateSections: (json['dateSections'] as List<dynamic>? ?? const [])
          .map((item) => ManagementTargetDateSection.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class MentorOverviewData {
  const MentorOverviewData({
    required this.student,
    required this.metrics,
    required this.targets,
    required this.recentSessions,
  });

  final AppUser student;
  final MentorMetrics metrics;
  final List<TargetSummary> targets;
  final List<SessionSummary> recentSessions;

  factory MentorOverviewData.fromJson(Map<String, dynamic> json) {
    return MentorOverviewData(
      student: AppUser.fromJson(_asMap(json['student'])),
      metrics: MentorMetrics.fromJson(_asMap(json['metrics'])),
      targets: (json['targets'] as List<dynamic>? ?? const [])
          .map((item) => TargetSummary.fromJson(_asMap(item)))
          .toList(),
      recentSessions: (json['recentSessions'] as List<dynamic>? ?? const [])
          .map((item) => SessionSummary.fromJson(_asMap(item)))
          .toList(),
    );
  }
}

class MentorCoveredSessionLog {
  const MentorCoveredSessionLog({
    required this.id,
    required this.notes,
    required this.focusScore,
    required this.completedQuestions,
    required this.behaviourStatus,
    required this.xpAwarded,
    required this.authorName,
    required this.authorRole,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String notes;
  final int focusScore;
  final int completedQuestions;
  final String behaviourStatus;
  final int xpAwarded;
  final String authorName;
  final String authorRole;
  final String? createdAt;
  final String? updatedAt;

  factory MentorCoveredSessionLog.fromJson(Map<String, dynamic> json) {
    return MentorCoveredSessionLog(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      focusScore: _asInt(json['focusScore']),
      completedQuestions: _asInt(json['completedQuestions']),
      behaviourStatus: (json['behaviourStatus'] ?? '').toString(),
      xpAwarded: _asInt(json['xpAwarded']),
      authorName: (json['authorName'] ?? '').toString(),
      authorRole: (json['authorRole'] ?? '').toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}

class MentorCoveredSession {
  const MentorCoveredSession({
    required this.id,
    required this.dateKey,
    required this.sessionType,
    required this.reason,
    this.subject,
    this.plannedTeacher,
    this.coverStaff,
    this.sessionLog,
  });

  final String id;
  final String dateKey;
  final String sessionType;
  final String reason;
  final SubjectSummary? subject;
  final TeacherSummary? plannedTeacher;
  final TeacherSummary? coverStaff;
  final MentorCoveredSessionLog? sessionLog;

  factory MentorCoveredSession.fromJson(Map<String, dynamic> json) {
    return MentorCoveredSession(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      dateKey: (json['dateKey'] ?? '').toString(),
      sessionType: (json['sessionType'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      subject: _asNullableMap(json['subject']) == null
          ? null
          : SubjectSummary.fromJson(_asMap(json['subject'])),
      plannedTeacher: _asNullableMap(json['plannedTeacher']) == null
          ? null
          : TeacherSummary.fromJson(_asMap(json['plannedTeacher'])),
      coverStaff: _asNullableMap(json['coverStaff']) == null
          ? null
          : TeacherSummary.fromJson(_asMap(json['coverStaff'])),
      sessionLog: _asNullableMap(json['sessionLog']) == null
          ? null
          : MentorCoveredSessionLog.fromJson(_asMap(json['sessionLog'])),
    );
  }
}

class MentorCoveredSessionsData {
  const MentorCoveredSessionsData({
    required this.student,
    required this.dateKey,
    required this.sessions,
  });

  final AppUser student;
  final String dateKey;
  final List<MentorCoveredSession> sessions;

  factory MentorCoveredSessionsData.fromJson(Map<String, dynamic> json) {
    return MentorCoveredSessionsData(
      student: AppUser.fromJson(_asMap(json['student'])),
      dateKey: (json['dateKey'] ?? '').toString(),
      sessions: (json['sessions'] as List<dynamic>? ?? const [])
          .map((item) => MentorCoveredSession.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.readAt,
    this.createdAt,
    this.studentId,
    this.studentName,
    this.criterionId,
    this.criterionTitle,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final String? readAt;
  final String? createdAt;
  final String? studentId;
  final String? studentName;
  final String? criterionId;
  final String? criterionTitle;

  AppNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    bool? isRead,
    String? readAt,
    String? createdAt,
    String? studentId,
    String? studentName,
    String? criterionId,
    String? criterionTitle,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      criterionId: criterionId ?? this.criterionId,
      criterionTitle: criterionTitle ?? this.criterionTitle,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      isRead: json['isRead'] == true,
      readAt: json['readAt']?.toString(),
      createdAt: json['createdAt']?.toString(),
      studentId: json['studentId']?.toString(),
      studentName: json['studentName']?.toString(),
      criterionId: json['criterionId']?.toString(),
      criterionTitle: json['criterionTitle']?.toString(),
    );
  }
}

class NotificationInboxData {
  const NotificationInboxData({
    required this.unreadCount,
    required this.notifications,
  });

  final int unreadCount;
  final List<AppNotification> notifications;

  factory NotificationInboxData.fromJson(Map<String, dynamic> json) {
    return NotificationInboxData(
      unreadCount: _asInt(json['unreadCount']),
      notifications: (json['notifications'] as List<dynamic>? ?? const [])
          .map((item) => AppNotification.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class TeacherWorkspaceData {
  const TeacherWorkspaceData({
    required this.session,
    required this.students,
    required this.teacherSubjects,
    required this.selectedStudent,
    required this.selectedDashboard,
    required this.timetable,
    required this.criteria,
    required this.draftMissions,
    required this.recentMissions,
    required this.studentResults,
    required this.notificationInbox,
    required this.targets,
  });

  final AuthSession session;
  final List<StudentSummary> students;
  final List<SubjectSummary> teacherSubjects;
  final StudentSummary selectedStudent;
  final StudentDashboardData selectedDashboard;
  final List<TodaySchedule> timetable;
  final List<CriterionOverview> criteria;
  final List<MissionPayload> draftMissions;
  final List<MissionPayload> recentMissions;
  final List<ResultHistoryItem> studentResults;
  final NotificationInboxData notificationInbox;
  final List<TargetSummary> targets;
}

class MentorWorkspaceData {
  const MentorWorkspaceData({
    required this.session,
    required this.students,
    required this.selectedStudent,
    required this.overview,
    required this.timetable,
    required this.notificationInbox,
  });

  final AuthSession session;
  final List<StudentSummary> students;
  final StudentSummary selectedStudent;
  final MentorOverviewData overview;
  final List<TodaySchedule> timetable;
  final NotificationInboxData notificationInbox;
}

class CriterionUnit {
  const CriterionUnit({
    required this.id,
    required this.title,
    required this.description,
    required this.baseOrder,
  });

  final String id;
  final String title;
  final String description;
  final int baseOrder;

  factory CriterionUnit.fromJson(Map<String, dynamic> json) {
    return CriterionUnit(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      baseOrder: _asInt(json['baseOrder']),
    );
  }
}

class CriterionDefinition {
  const CriterionDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.baseOrder,
    required this.requiredWordCount,
    required this.learningPassRate,
    required this.isActive,
  });

  final String id;
  final String title;
  final String description;
  final int baseOrder;
  final int requiredWordCount;
  final int learningPassRate;
  final bool isActive;

  factory CriterionDefinition.fromJson(Map<String, dynamic> json) {
    return CriterionDefinition(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      baseOrder: _asInt(json['baseOrder']),
      requiredWordCount: _asInt(json['requiredWordCount']),
      learningPassRate: _asInt(json['learningPassRate']),
      isActive: json['isActive'] != false,
    );
  }
}

class CriterionProgress {
  const CriterionProgress({
    required this.id,
    required this.criterionState,
    required this.learningStatus,
    required this.learningCheckBlockOrder,
    required this.attemptsUsed,
    required this.latestLearningCheckScore,
    required this.appendedBlockIds,
    required this.essayText,
    required this.wordCount,
    required this.submissionUnlocked,
    required this.completed,
    required this.xpAwarded,
    this.learningCompletedAt,
    this.essayBuilderUnlockedAt,
    this.submittedAt,
    this.approvedAt,
    this.revisionRequestedAt,
  });

  final String id;
  final String criterionState;
  final String learningStatus;
  final List<String> learningCheckBlockOrder;
  final int attemptsUsed;
  final int latestLearningCheckScore;
  final List<String> appendedBlockIds;
  final String essayText;
  final int wordCount;
  final bool submissionUnlocked;
  final bool completed;
  final int xpAwarded;
  final String? learningCompletedAt;
  final String? essayBuilderUnlockedAt;
  final String? submittedAt;
  final String? approvedAt;
  final String? revisionRequestedAt;

  bool get learningRequired => criterionState == 'learning_required';
  bool get learningCheckActive => criterionState == 'learning_check_active';
  bool get essayBuilderUnlocked => criterionState == 'essay_builder_unlocked';
  bool get readyForSubmission => criterionState == 'ready_for_submission';
  bool get submitted => criterionState == 'submitted';
  bool get approved => criterionState == 'approved';
  bool get revisionRequested => criterionState == 'revision_requested';
  bool get learningLocked => learningStatus == 'locked_review_required';

  factory CriterionProgress.fromJson(Map<String, dynamic> json) {
    return CriterionProgress(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      criterionState: (json['criterionState'] ?? 'learning_required')
          .toString(),
      learningStatus: (json['learningStatus'] ?? 'pending').toString(),
      learningCheckBlockOrder: _asStringList(json['learningCheckBlockOrder']),
      attemptsUsed: _asInt(json['attemptsUsed']),
      latestLearningCheckScore: _asInt(json['latestLearningCheckScore']),
      appendedBlockIds: _asStringList(json['appendedBlockIds']),
      essayText: (json['essayText'] ?? '').toString(),
      wordCount: _asInt(json['wordCount']),
      submissionUnlocked: json['submissionUnlocked'] == true,
      completed: json['completed'] == true,
      xpAwarded: _asInt(json['xpAwarded']),
      learningCompletedAt: json['learningCompletedAt']?.toString(),
      essayBuilderUnlockedAt: json['essayBuilderUnlockedAt']?.toString(),
      submittedAt: json['submittedAt']?.toString(),
      approvedAt: json['approvedAt']?.toString(),
      revisionRequestedAt: json['revisionRequestedAt']?.toString(),
    );
  }
}

class CriterionFlags {
  const CriterionFlags({
    required this.learningContentReady,
    required this.learningCompleted,
    required this.learningCheckLocked,
    required this.attemptsRemaining,
    required this.learningCheckUnlocked,
    required this.essayBuilderUnlocked,
    required this.submissionReady,
    required this.teacherReviewPending,
    required this.revisionRequested,
    required this.approved,
  });

  final bool learningContentReady;
  final bool learningCompleted;
  final bool learningCheckLocked;
  final int attemptsRemaining;
  final bool learningCheckUnlocked;
  final bool essayBuilderUnlocked;
  final bool submissionReady;
  final bool teacherReviewPending;
  final bool revisionRequested;
  final bool approved;

  factory CriterionFlags.fromJson(Map<String, dynamic> json) {
    return CriterionFlags(
      learningContentReady: json['learningContentReady'] == true,
      learningCompleted: json['learningCompleted'] == true,
      learningCheckLocked: json['learningCheckLocked'] == true,
      attemptsRemaining: _asInt(json['attemptsRemaining']),
      learningCheckUnlocked: json['learningCheckUnlocked'] == true,
      essayBuilderUnlocked: json['essayBuilderUnlocked'] == true,
      submissionReady: json['submissionReady'] == true,
      teacherReviewPending: json['teacherReviewPending'] == true,
      revisionRequested: json['revisionRequested'] == true,
      approved: json['approved'] == true,
    );
  }
}

class CriterionOverview {
  const CriterionOverview({
    required this.subject,
    required this.unit,
    required this.criterion,
    required this.progress,
    required this.flags,
  });

  final SubjectSummary? subject;
  final CriterionUnit? unit;
  final CriterionDefinition criterion;
  final CriterionProgress progress;
  final CriterionFlags flags;

  factory CriterionOverview.fromJson(Map<String, dynamic> json) {
    return CriterionOverview(
      subject: _asNullableMap(json['subject']) == null
          ? null
          : SubjectSummary.fromJson(_asMap(json['subject'])),
      unit: _asNullableMap(json['unit']) == null
          ? null
          : CriterionUnit.fromJson(_asMap(json['unit'])),
      criterion: CriterionDefinition.fromJson(_asMap(json['criterion'])),
      progress: CriterionProgress.fromJson(_asMap(json['progress'])),
      flags: CriterionFlags.fromJson(_asMap(json['flags'])),
    );
  }
}

class StudentCriteriaData {
  const StudentCriteriaData({required this.student, required this.criteria});

  final StudentSummary student;
  final List<CriterionOverview> criteria;

  factory StudentCriteriaData.fromJson(Map<String, dynamic> json) {
    final studentJson = _asMap(json['student']);

    return StudentCriteriaData(
      student: StudentSummary(
        id: (studentJson['id'] ?? studentJson['_id'] ?? '').toString(),
        name: (studentJson['name'] ?? '').toString(),
        xp: _asInt(studentJson['xp']),
        streak: _asInt(studentJson['streak']),
        yearGroup: (studentJson['yearGroup'] ?? '').toString(),
      ),
      criteria: (json['criteria'] as List<dynamic>? ?? const [])
          .map((item) => CriterionOverview.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class LearningSection {
  const LearningSection({
    required this.heading,
    required this.body,
    required this.baseOrder,
  });

  final String heading;
  final String body;
  final int baseOrder;

  factory LearningSection.fromJson(Map<String, dynamic> json) {
    return LearningSection(
      heading: (json['heading'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      baseOrder: _asInt(json['baseOrder']),
    );
  }
}

class CriterionLearningContent {
  const CriterionLearningContent({
    required this.id,
    required this.title,
    required this.summary,
    required this.status,
    required this.source,
    required this.sections,
    this.approvedAt,
  });

  final String id;
  final String title;
  final String summary;
  final String status;
  final String source;
  final List<LearningSection> sections;
  final String? approvedAt;

  factory CriterionLearningContent.fromJson(Map<String, dynamic> json) {
    return CriterionLearningContent(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .map((item) => LearningSection.fromJson(_asMap(item)))
          .toList(growable: false),
      approvedAt: json['approvedAt']?.toString(),
    );
  }
}

class CriterionDetailData {
  const CriterionDetailData({
    required this.studentName,
    required this.subject,
    required this.unit,
    required this.criterion,
    required this.progress,
    required this.flags,
    this.learningContent,
  });

  final String studentName;
  final SubjectSummary? subject;
  final CriterionUnit? unit;
  final CriterionDefinition criterion;
  final CriterionProgress progress;
  final CriterionFlags flags;
  final CriterionLearningContent? learningContent;

  factory CriterionDetailData.fromJson(Map<String, dynamic> json) {
    final studentJson = _asMap(json['student']);

    return CriterionDetailData(
      studentName: (studentJson['name'] ?? '').toString(),
      subject: _asNullableMap(json['subject']) == null
          ? null
          : SubjectSummary.fromJson(_asMap(json['subject'])),
      unit: _asNullableMap(json['unit']) == null
          ? null
          : CriterionUnit.fromJson(_asMap(json['unit'])),
      criterion: CriterionDefinition.fromJson(_asMap(json['criterion'])),
      progress: CriterionProgress.fromJson(_asMap(json['progress'])),
      flags: CriterionFlags.fromJson(_asMap(json['flags'])),
      learningContent: _asNullableMap(json['learningContent']) == null
          ? null
          : CriterionLearningContent.fromJson(_asMap(json['learningContent'])),
    );
  }
}

class CriterionBlock {
  const CriterionBlock({
    required this.id,
    required this.type,
    required this.phase,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.generatedSentence,
    required this.baseOrder,
    required this.isRequired,
  });

  final String id;
  final String type;
  final String phase;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String generatedSentence;
  final int baseOrder;
  final bool isRequired;

  factory CriterionBlock.fromJson(Map<String, dynamic> json) {
    return CriterionBlock(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      phase: (json['phase'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      options: _asStringList(json['options']),
      correctIndex: _asInt(json['correctIndex']),
      generatedSentence: (json['generatedSentence'] ?? '').toString(),
      baseOrder: _asInt(json['baseOrder']),
      isRequired: json['isRequired'] != false,
    );
  }
}

class CriterionBlocksData {
  const CriterionBlocksData({
    required this.criterion,
    required this.progress,
    required this.flags,
    required this.blocks,
  });

  final CriterionDefinition criterion;
  final CriterionProgress progress;
  final CriterionFlags flags;
  final List<CriterionBlock> blocks;

  factory CriterionBlocksData.fromJson(Map<String, dynamic> json) {
    return CriterionBlocksData(
      criterion: CriterionDefinition.fromJson(_asMap(json['criterion'])),
      progress: CriterionProgress.fromJson(_asMap(json['progress'])),
      flags: CriterionFlags.fromJson(_asMap(json['flags'])),
      blocks: (json['blocks'] as List<dynamic>? ?? const [])
          .map((item) => CriterionBlock.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class LearningCheckAttemptResult {
  const LearningCheckAttemptResult({
    required this.score,
    required this.passRate,
    required this.passed,
    required this.correctAnswers,
    required this.totalQuestions,
  });

  final int score;
  final int passRate;
  final bool passed;
  final int correctAnswers;
  final int totalQuestions;

  factory LearningCheckAttemptResult.fromJson(Map<String, dynamic> json) {
    return LearningCheckAttemptResult(
      score: _asInt(json['score']),
      passRate: _asInt(json['passRate']),
      passed: json['passed'] == true,
      correctAnswers: _asInt(json['correctAnswers']),
      totalQuestions: _asInt(json['totalQuestions']),
    );
  }
}

class LearningCheckSubmissionData {
  const LearningCheckSubmissionData({
    required this.progress,
    required this.flags,
    required this.attemptResult,
  });

  final CriterionProgress progress;
  final CriterionFlags flags;
  final LearningCheckAttemptResult attemptResult;

  factory LearningCheckSubmissionData.fromJson(Map<String, dynamic> json) {
    return LearningCheckSubmissionData(
      progress: CriterionProgress.fromJson(_asMap(json['progress'])),
      flags: CriterionFlags.fromJson(_asMap(json['flags'])),
      attemptResult: LearningCheckAttemptResult.fromJson(
        _asMap(json['attemptResult']),
      ),
    );
  }
}

class CriterionProgressUpdate {
  const CriterionProgressUpdate({required this.progress, required this.flags});

  final CriterionProgress progress;
  final CriterionFlags flags;

  factory CriterionProgressUpdate.fromJson(Map<String, dynamic> json) {
    return CriterionProgressUpdate(
      progress: CriterionProgress.fromJson(_asMap(json['progress'])),
      flags: CriterionFlags.fromJson(_asMap(json['flags'])),
    );
  }
}

class EssayBuilderAppendData {
  const EssayBuilderAppendData({
    required this.appendedBlock,
    required this.progress,
    required this.flags,
  });

  final CriterionBlock appendedBlock;
  final CriterionProgress progress;
  final CriterionFlags flags;

  factory EssayBuilderAppendData.fromJson(Map<String, dynamic> json) {
    return EssayBuilderAppendData(
      appendedBlock: CriterionBlock.fromJson(_asMap(json['appendedBlock'])),
      progress: CriterionProgress.fromJson(_asMap(json['progress'])),
      flags: CriterionFlags.fromJson(_asMap(json['flags'])),
    );
  }
}

class CriterionSubmissionData {
  const CriterionSubmissionData({
    required this.progress,
    required this.flags,
    required this.xpAwardedNow,
    required this.notificationsCreated,
  });

  final CriterionProgress progress;
  final CriterionFlags flags;
  final int xpAwardedNow;
  final int notificationsCreated;

  factory CriterionSubmissionData.fromJson(Map<String, dynamic> json) {
    return CriterionSubmissionData(
      progress: CriterionProgress.fromJson(_asMap(json['progress'])),
      flags: CriterionFlags.fromJson(_asMap(json['flags'])),
      xpAwardedNow: _asInt(json['xpAwardedNow']),
      notificationsCreated: _asInt(json['notificationsCreated']),
    );
  }
}

class CriterionReviewData {
  const CriterionReviewData({
    required this.progress,
    required this.flags,
    required this.reviewAction,
  });

  final CriterionProgress progress;
  final CriterionFlags flags;
  final String reviewAction;

  factory CriterionReviewData.fromJson(Map<String, dynamic> json) {
    return CriterionReviewData(
      progress: CriterionProgress.fromJson(_asMap(json['progress'])),
      flags: CriterionFlags.fromJson(_asMap(json['flags'])),
      reviewAction: (json['reviewAction'] ?? '').toString(),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<dynamic, dynamic>) {
    return value.cast<String, dynamic>();
  }

  if (value is String || value is num) {
    final id = value.toString();
    return <String, dynamic>{'id': id, '_id': id};
  }

  // WHY: Some backend payloads can return relation ids as strings instead of
  // populated objects, so map parsing must fail soft to keep screens usable.
  return const <String, dynamic>{};
}

Map<String, dynamic>? _asNullableMap(Object? value) {
  if (value is Map<dynamic, dynamic>) {
    return value.cast<String, dynamic>();
  }

  if (value is String || value is num) {
    final id = value.toString();
    return <String, dynamic>{'id': id, '_id': id};
  }

  return null;
}

List<String> _asStringList(Object? value) {
  if (value is List<dynamic>) {
    return value.map((item) => item.toString()).toList(growable: false);
  }

  return const [];
}

String? _asOptionalString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _asNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return int.tryParse(value.toString());
}

DateTime? _asNullableDateTime(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}
