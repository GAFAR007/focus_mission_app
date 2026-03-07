/**
 * WHAT:
 * FocusMissionApi wraps backend requests for auth, timetable, missions, and
 * criterion progression.
 * WHY:
 * The Flutter UI needs one stable service boundary so learning enforcement,
 * learning-check attempts, essay-builder actions, and teacher review stay
 * consistent across screens.
 * HOW:
 * Send authenticated JSON requests to the Express API and decode the responses
 * into typed frontend models.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import '../../features/teacher/models/analytics_models.dart';
import '../../shared/models/focus_mission_models.dart';

class FocusMissionApi {
  FocusMissionApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _requestJson(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );

    return AuthSession.fromJson(json);
  }

  Future<AppUser> updateProfileAvatar({
    required String token,
    required String avatar,
    required String avatarSeed,
  }) async {
    final json = await _requestJson(
      'PATCH',
      '/auth/me/avatar',
      token: token,
      body: {'avatar': avatar, 'avatarSeed': avatarSeed},
    );

    return AppUser.fromJson(
      (json['user'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<StudentDashboardData> fetchStudentDashboard({
    required String token,
    required String studentId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/student/dashboard/$studentId',
      token: token,
    );

    return StudentDashboardData.fromJson(json);
  }

  Future<List<StudentSummary>> fetchStudents({required String token}) async {
    final json = await _requestJson('GET', '/teacher/students', token: token);
    final students = json['students'] as List<dynamic>? ?? const [];

    return students
        .map(
          (item) => StudentSummary.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  Future<List<DailyTrendPoint>> getDailyTrend({
    required String token,
    required String studentId,
    String? from,
    String? to,
  }) async {
    final json = await _requestList(
      'GET',
      '/teacher/students/$studentId/daily-trend${_buildDateRangeQuery(from: from, to: to)}',
      token: token,
    );
    return json
        .map(
          (item) => DailyTrendPoint.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<SessionBreakdown>> getSessionBreakdown({
    required String token,
    required String studentId,
    String? from,
    String? to,
  }) async {
    final json = await _requestList(
      'GET',
      '/teacher/students/$studentId/session-breakdown${_buildDateRangeQuery(from: from, to: to)}',
      token: token,
    );
    return json
        .map(
          (item) => SessionBreakdown.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<SubjectAnalytics>> getSubjectAnalytics({
    required String token,
    required String studentId,
    String? from,
    String? to,
  }) async {
    final json = await _requestList(
      'GET',
      '/teacher/students/$studentId/subjects${_buildDateRangeQuery(from: from, to: to)}',
      token: token,
    );
    return json
        .map(
          (item) => SubjectAnalytics.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<BehaviourDistribution>> getBehaviourTrend({
    required String token,
    required String studentId,
    String? from,
    String? to,
  }) async {
    final json = await _requestList(
      'GET',
      '/teacher/students/$studentId/behaviour-trend${_buildDateRangeQuery(from: from, to: to)}',
      token: token,
    );
    return json
        .map(
          (item) => BehaviourDistribution.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<StudentCriteriaData> fetchStudentCriteria({
    required String token,
    required String studentId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/criterion/student/$studentId',
      token: token,
    );

    return StudentCriteriaData.fromJson(json);
  }

  Future<CriterionDetailData> fetchCriterionDetail({
    required String token,
    required String studentId,
    required String criterionId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/criterion/student/$studentId/$criterionId',
      token: token,
    );

    return CriterionDetailData.fromJson(json);
  }

  Future<CriterionProgressUpdate> completeCriterionLearning({
    required String token,
    required String studentId,
    required String criterionId,
  }) async {
    final json = await _requestJson(
      'POST',
      '/criterion/student/$studentId/$criterionId/learning/complete',
      token: token,
    );

    return CriterionProgressUpdate.fromJson(json);
  }

  Future<CriterionBlocksData> fetchLearningCheckBlocks({
    required String token,
    required String studentId,
    required String criterionId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/criterion/student/$studentId/$criterionId/blocks/learning-check',
      token: token,
    );

    return CriterionBlocksData.fromJson(json);
  }

  Future<LearningCheckSubmissionData> submitLearningCheckAttempt({
    required String token,
    required String studentId,
    required String criterionId,
    required Map<String, int> answers,
  }) async {
    final json = await _requestJson(
      'POST',
      '/criterion/student/$studentId/$criterionId/blocks/learning-check/submit',
      token: token,
      body: {
        'answers': answers.entries
            .map(
              (entry) => {'blockId': entry.key, 'selectedIndex': entry.value},
            )
            .toList(growable: false),
      },
    );

    return LearningCheckSubmissionData.fromJson(json);
  }

  Future<CriterionBlocksData> resetLearningCheck({
    required String token,
    required String studentId,
    required String criterionId,
  }) async {
    final json = await _requestJson(
      'POST',
      '/criterion/student/$studentId/$criterionId/blocks/learning-check/reset',
      token: token,
    );

    return CriterionBlocksData.fromJson(json);
  }

  Future<CriterionBlocksData> fetchEssayBuilderBlocks({
    required String token,
    required String studentId,
    required String criterionId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/criterion/student/$studentId/$criterionId/blocks/essay-builder',
      token: token,
    );

    return CriterionBlocksData.fromJson(json);
  }

  Future<EssayBuilderAppendData> appendEssayBuilderBlock({
    required String token,
    required String studentId,
    required String criterionId,
    required String blockId,
  }) async {
    final json = await _requestJson(
      'POST',
      '/criterion/student/$studentId/$criterionId/blocks/essay-builder/append',
      token: token,
      body: {'blockId': blockId},
    );

    return EssayBuilderAppendData.fromJson(json);
  }

  Future<CriterionSubmissionData> submitCriterion({
    required String token,
    required String studentId,
    required String criterionId,
  }) async {
    final json = await _requestJson(
      'POST',
      '/criterion/student/$studentId/$criterionId/submit',
      token: token,
    );

    return CriterionSubmissionData.fromJson(json);
  }

  Future<CriterionReviewData> reviewCriterion({
    required String token,
    required String studentId,
    required String criterionId,
    required String action,
  }) async {
    final json = await _requestJson(
      'POST',
      '/criterion/student/$studentId/$criterionId/review',
      token: token,
      body: {'action': action},
    );

    return CriterionReviewData.fromJson(json);
  }

  Future<NotificationInboxData> fetchNotificationInbox({
    required String token,
  }) async {
    final json = await _requestJson('GET', '/notifications', token: token);

    return NotificationInboxData.fromJson(json);
  }

  Future<AppNotification> markNotificationRead({
    required String token,
    required String notificationId,
  }) async {
    final json = await _requestJson(
      'PATCH',
      '/notifications/$notificationId/read',
      token: token,
    );

    return AppNotification.fromJson(
      (json['notification'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<List<MissionPayload>> fetchTeacherRecentMissions({
    required String token,
    required String studentId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/teacher/missions/recent/$studentId',
      token: token,
    );
    final missions = json['missions'] as List<dynamic>? ?? const [];

    return missions
        .map(
          (item) => MissionPayload.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<MissionPayload>> fetchManagementStudentResults({
    required String token,
    required String studentId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/management/students/$studentId/results',
      token: token,
    );
    final missions = json['missions'] as List<dynamic>? ?? const [];

    return missions
        .map(
          (item) => MissionPayload.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<AppUser> createManagementUser({
    required String token,
    required String role,
    required String name,
    required String email,
    required String password,
    String subjectSpecialty = '',
  }) async {
    final json = await _requestJson(
      'POST',
      '/management/users',
      token: token,
      body: {
        'role': role,
        'name': name,
        'email': email,
        'password': password,
        if (subjectSpecialty.trim().isNotEmpty)
          'subjectSpecialty': subjectSpecialty.trim(),
      },
    );

    return AppUser.fromJson(
      (json['user'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<List<MissionPayload>> fetchTeacherDraftMissions({
    required String token,
    required String studentId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/teacher/missions/drafts/$studentId',
      token: token,
    );
    final missions = json['missions'] as List<dynamic>? ?? const [];

    return missions
        .map(
          (item) => MissionPayload.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<MentorOverviewData> fetchMentorOverview({
    required String token,
    required String studentId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/mentor/overview/$studentId',
      token: token,
    );

    return MentorOverviewData.fromJson(json);
  }

  Future<List<TodaySchedule>> fetchStudentTimetable({
    required String token,
    required String studentId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/student/timetable/$studentId',
      token: token,
    );
    final timetable = json['timetable'] as List<dynamic>? ?? const [];

    return timetable
        .map(
          (item) => TodaySchedule.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<MissionPayload>> fetchStudentAssignedMissions({
    required String token,
    required String studentId,
    required String subjectId,
    required String sessionType,
  }) async {
    final json = await _requestJson(
      'GET',
      '/student/missions/assigned/$studentId?subjectId=$subjectId&sessionType=$sessionType',
      token: token,
    );
    final missions = json['missions'] as List<dynamic>? ?? const [];

    return missions
        .map(
          (item) => MissionPayload.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<StartedMission> startSession({
    required String token,
    required String studentId,
    required String subjectId,
    required String sessionType,
    String? missionId,
  }) async {
    final json = await _requestJson(
      'POST',
      '/student/session/start',
      token: token,
      body: {
        'studentId': studentId,
        'subjectId': subjectId,
        'sessionType': sessionType,
        if (missionId != null && missionId.isNotEmpty) 'missionId': missionId,
      },
    );

    return StartedMission.fromJson(json);
  }

  Future<AppUser?> createSessionLog({
    required String token,
    required String studentId,
    required String subjectId,
    required String sessionType,
    required int focusScore,
    required int completedQuestions,
    required String behaviourStatus,
    required String notes,
    int xpAwarded = 20,
  }) async {
    final json = await _requestJson(
      'POST',
      '/teacher/session-log',
      token: token,
      body: {
        'studentId': studentId,
        'subjectId': subjectId,
        'sessionType': sessionType,
        'focusScore': focusScore,
        'completedQuestions': completedQuestions,
        'behaviourStatus': behaviourStatus,
        'notes': notes,
        'xpAwarded': xpAwarded,
      },
    );

    final student = json['student'];

    if (student is Map<dynamic, dynamic>) {
      return AppUser.fromJson(student.cast<String, dynamic>());
    }

    return null;
  }

  Future<void> updateDifficulty({
    required String token,
    required String studentId,
    required String difficulty,
  }) async {
    await _requestJson(
      'PATCH',
      '/mentor/difficulty/$studentId',
      token: token,
      body: {'preferredDifficulty': difficulty.toLowerCase()},
    );
  }

  Future<TargetSummary> createTarget({
    required String token,
    required String studentId,
    required String title,
    String description = '',
    String difficulty = 'medium',
    String targetType = 'custom',
    int stars = 0,
    String? awardDateKey,
  }) async {
    final json = await _requestJson(
      'POST',
      '/mentor/targets',
      token: token,
      body: {
        'studentId': studentId,
        'title': title,
        'description': description,
        'difficulty': difficulty,
        'targetType': targetType,
        'stars': stars,
        if (awardDateKey != null && awardDateKey.isNotEmpty)
          'awardDateKey': awardDateKey,
      },
    );

    return TargetSummary.fromJson(
      (json['target'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<TargetSummary> updateTarget({
    required String token,
    required String targetId,
    int? stars,
    String? status,
    String? awardDateKey,
  }) async {
    final body =
        <String, dynamic>{
          'stars': stars,
          'status': status,
          'awardDateKey': awardDateKey,
        }..removeWhere(
          (key, value) =>
              value == null || (value is String && value.trim().isEmpty),
        );

    final json = await _requestJson(
      'PATCH',
      '/mentor/targets/$targetId',
      token: token,
      body: body,
    );

    return TargetSummary.fromJson(
      (json['target'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<TeacherWorkspaceData> loadTeacherWorkspace({
    required AuthSession session,
    String? selectedStudentId,
  }) async {
    final students = await fetchStudents(token: session.token);

    if (students.isEmpty) {
      throw const FocusMissionApiException(
        'No students are assigned to this teacher yet.',
      );
    }

    final resolvedStudentId = (selectedStudentId ?? '').trim();
    final selectedStudent = students.firstWhere(
      (student) => student.id == resolvedStudentId,
      orElse: () => students.first,
    );
    final selectedDashboard = await fetchStudentDashboard(
      token: session.token,
      studentId: selectedStudent.id,
    );
    final timetable = await fetchStudentTimetable(
      token: session.token,
      studentId: selectedStudent.id,
    );
    final criteria = await fetchStudentCriteria(
      token: session.token,
      studentId: selectedStudent.id,
    );
    final notificationInbox = await fetchNotificationInbox(
      token: session.token,
    );
    final draftMissions = await fetchTeacherDraftMissions(
      token: session.token,
      studentId: selectedStudent.id,
    );
    final recentMissions = await fetchTeacherRecentMissions(
      token: session.token,
      studentId: selectedStudent.id,
    );
    final mentorOverview = await fetchMentorOverview(
      token: session.token,
      studentId: selectedStudent.id,
    );

    return TeacherWorkspaceData(
      session: session,
      students: students,
      selectedStudent: selectedStudent,
      selectedDashboard: selectedDashboard,
      timetable: timetable,
      criteria: criteria.criteria,
      draftMissions: draftMissions,
      recentMissions: recentMissions,
      notificationInbox: notificationInbox,
      targets: mentorOverview.targets,
    );
  }

  Future<MentorWorkspaceData> loadMentorWorkspace({
    required AuthSession mentorSession,
    String? selectedStudentId,
  }) async {
    final assignedStudentIds = mentorSession.user.assignedStudents;

    if (assignedStudentIds.isEmpty) {
      throw const FocusMissionApiException(
        'No students are assigned to this mentor yet.',
      );
    }

    final normalizedSelectedStudentId = (selectedStudentId ?? '').trim();
    final resolvedStudentId =
        assignedStudentIds.contains(normalizedSelectedStudentId)
        ? normalizedSelectedStudentId
        : assignedStudentIds.first;
    final studentOverviews = <String, MentorOverviewData>{};
    for (final studentId in assignedStudentIds) {
      studentOverviews[studentId] = await fetchMentorOverview(
        token: mentorSession.token,
        studentId: studentId,
      );
    }

    final selectedOverview = studentOverviews[resolvedStudentId];
    if (selectedOverview == null) {
      throw const FocusMissionApiException(
        'Could not load mentor student overview.',
      );
    }

    final students = studentOverviews.values
        .map(
          (overview) => StudentSummary(
            id: overview.student.id,
            name: overview.student.name,
            xp: overview.student.xp,
            streak: overview.student.streak,
          ),
        )
        .toList(growable: false);
    final selectedStudent = students.firstWhere(
      (student) => student.id == resolvedStudentId,
      orElse: () => students.first,
    );
    final timetable = await fetchStudentTimetable(
      token: mentorSession.token,
      studentId: resolvedStudentId,
    );
    final notificationInbox = await fetchNotificationInbox(
      token: mentorSession.token,
    );

    return MentorWorkspaceData(
      session: mentorSession,
      students: students,
      selectedStudent: selectedStudent,
      overview: selectedOverview,
      timetable: timetable,
      notificationInbox: notificationInbox,
    );
  }

  Future<UploadedSourceDraft> uploadTeacherSourceDraft({
    required String token,
    required String subjectId,
    required String sessionType,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/teacher/ai/extract-source'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['subjectId'] = subjectId;
    request.fields['sessionType'] = sessionType;
    request.files.add(
      http.MultipartFile.fromBytes('sourceFile', fileBytes, filename: fileName),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw FocusMissionApiException(
        (json['message'] ?? 'Upload failed.').toString(),
      );
    }

    return UploadedSourceDraft.fromJson(
      (json['draft'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<UploadedCriterionSourceDraft> uploadCriterionSourceDraft({
    required String token,
    required String criterionId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/teacher/ai/extract-unit-source'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['criterionId'] = criterionId;
    request.files.add(
      http.MultipartFile.fromBytes('sourceFile', fileBytes, filename: fileName),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw FocusMissionApiException(
        (json['message'] ?? 'Upload failed.').toString(),
      );
    }

    return UploadedCriterionSourceDraft.fromJson(
      (json['draft'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<CriterionAiDraft> generateCriterionLearningDraft({
    required String token,
    required String criterionId,
    required String unitText,
  }) async {
    final json = await _requestJson(
      'POST',
      '/teacher/ai/generate-learning-and-blocks',
      token: token,
      body: {'criterionId': criterionId, 'unitText': unitText},
    );

    return CriterionAiDraft.fromJson(
      (json['draft'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<CriterionAiDraft> approveCriterionLearningDraft({
    required String token,
    required CriterionAiDraft draft,
  }) async {
    final json = await _requestJson(
      'POST',
      '/teacher/approve-learning-and-blocks',
      token: token,
      body: {
        'criterionId': draft.criterion.id,
        'learningContent': {
          'title': draft.learningContent.title,
          'summary': draft.learningContent.summary,
          'sections': draft.learningContent.sections
              .map(
                (section) => {
                  'heading': section.heading,
                  'body': section.body,
                  'baseOrder': section.baseOrder,
                },
              )
              .toList(growable: false),
        },
        'learningCheckBlocks': draft.learningCheckBlocks
            .map(
              (block) => {
                'type': block.type,
                'phase': block.phase,
                'prompt': block.prompt,
                'options': block.options,
                'correctIndex': block.correctIndex,
                'generatedSentence': block.generatedSentence,
                'baseOrder': block.baseOrder,
                'isRequired': block.isRequired,
              },
            )
            .toList(growable: false),
        'essayBuilderBlocks': draft.essayBuilderBlocks
            .map(
              (block) => {
                'type': block.type,
                'phase': block.phase,
                'prompt': block.prompt,
                'options': block.options,
                'correctIndex': block.correctIndex,
                'generatedSentence': block.generatedSentence,
                'baseOrder': block.baseOrder,
                'isRequired': block.isRequired,
              },
            )
            .toList(growable: false),
      },
    );

    return CriterionAiDraft.fromJson(
      (json['draft'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<MissionPayload> generateTeacherMission({
    required String token,
    required String studentId,
    required String subjectId,
    required String sessionType,
    required String targetDate,
    required String title,
    required String unitText,
    String sourceRawText = '',
    String draftFormat = 'QUESTIONS',
    String essayMode = '',
    String missionDraftId = '',
    required String difficulty,
    required int questionCount,
    required int xpReward,
    List<String> taskCodes = const [],
    String sourceFileName = '',
    String sourceFileType = '',
  }) async {
    final json = await _requestJson(
      'POST',
      '/teacher/missions/generate',
      token: token,
      body: {
        'studentId': studentId,
        'subjectId': subjectId,
        'sessionType': sessionType,
        'targetDate': targetDate,
        'title': title,
        'unitText': unitText,
        'sourceRawText': sourceRawText,
        'draftFormat': draftFormat,
        if (essayMode.trim().isNotEmpty) 'essayMode': essayMode,
        if (missionDraftId.trim().isNotEmpty) 'missionDraftId': missionDraftId,
        'difficulty': difficulty,
        'questionCount': questionCount,
        'xpReward': xpReward,
        'taskCodes': taskCodes,
        'sourceFileName': sourceFileName,
        'sourceFileType': sourceFileType,
      },
    );

    return MissionPayload.fromJson(
      (json['mission'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<MissionPayload> previewTeacherMission({
    required String token,
    required String studentId,
    required String subjectId,
    required String sessionType,
    required String targetDate,
    required String title,
    required String unitText,
    String sourceRawText = '',
    String draftFormat = 'QUESTIONS',
    String essayMode = '',
    String missionDraftId = '',
    required String difficulty,
    required int questionCount,
    required int xpReward,
    List<String> taskCodes = const [],
    String sourceFileName = '',
    String sourceFileType = '',
  }) async {
    final json = await _requestJson(
      'POST',
      '/teacher/missions/preview',
      token: token,
      body: {
        'studentId': studentId,
        'subjectId': subjectId,
        'sessionType': sessionType,
        'targetDate': targetDate,
        'title': title,
        'unitText': unitText,
        'sourceRawText': sourceRawText,
        'draftFormat': draftFormat,
        if (essayMode.trim().isNotEmpty) 'essayMode': essayMode,
        if (missionDraftId.trim().isNotEmpty) 'missionDraftId': missionDraftId,
        'difficulty': difficulty,
        'questionCount': questionCount,
        'xpReward': xpReward,
        'taskCodes': taskCodes,
        'sourceFileName': sourceFileName,
        'sourceFileType': sourceFileType,
      },
    );

    return MissionPayload.fromJson(
      (json['mission'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<MissionPayload> updateTeacherMission({
    required String token,
    required String missionId,
    String? sessionType,
    String? targetDate,
    required String title,
    required String teacherNote,
    required String sourceUnitText,
    String sourceRawText = '',
    required String difficulty,
    required int xpReward,
    List<String> taskCodes = const [],
    required List<MissionQuestion> questions,
    String? draftFormat,
    String? essayMode,
    Map<String, dynamic>? draftJson,
    String sourceFileName = '',
    String sourceFileType = '',
    String status = 'draft',
  }) async {
    final json = await _requestJson(
      'PATCH',
      '/teacher/missions/$missionId',
      token: token,
      body: {
        ...?sessionType == null ? null : {'sessionType': sessionType},
        ...?targetDate == null ? null : {'targetDate': targetDate},
        'title': title,
        'teacherNote': teacherNote,
        'sourceUnitText': sourceUnitText,
        'sourceRawText': sourceRawText,
        'difficulty': difficulty,
        'xpReward': xpReward,
        'taskCodes': taskCodes,
        'sourceFileName': sourceFileName,
        'sourceFileType': sourceFileType,
        ...?draftFormat == null ? null : {'draftFormat': draftFormat},
        ...?essayMode == null ? null : {'essayMode': essayMode},
        ...?draftJson == null ? null : {'draftJson': draftJson},
        'status': status,
        'questions': questions
            .map(
              (question) => {
                'answerMode': question.answerMode,
                'prompt': question.prompt,
                'learningText': question.learningText,
                'options': question.options,
                'correctIndex': question.correctIndex,
                'explanation': question.explanation,
                'expectedAnswer': question.expectedAnswer,
                'minWordCount': question.minWordCount,
              },
            )
            .toList(growable: false),
      },
    );

    return MissionPayload.fromJson(
      (json['mission'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<MissionPayload> updateTeacherMissionStatus({
    required String token,
    required String missionId,
    required String status,
  }) async {
    final json = await _requestJson(
      'PATCH',
      '/teacher/missions/$missionId',
      token: token,
      body: {'status': status},
    );

    return MissionPayload.fromJson(
      (json['mission'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<void> deleteTeacherMission({
    required String token,
    required String missionId,
  }) async {
    await _requestJson('DELETE', '/teacher/missions/$missionId', token: token);
  }

  Future<MissionPayload> reextractTeacherMissionSource({
    required String token,
    required String missionId,
  }) async {
    final json = await _requestJson(
      'POST',
      '/teacher/missions/$missionId/reextract-source',
      token: token,
    );

    return MissionPayload.fromJson(
      (json['mission'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<ResultPackageData> getTeacherResultPackage({
    required String token,
    required String resultPackageId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/teacher/results/$resultPackageId',
      token: token,
    );

    return ResultPackageData.fromJson(
      (json['resultPackage'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<ResultPackageData> getManagementResultPackage({
    required String token,
    required String resultPackageId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/management/results/$resultPackageId',
      token: token,
    );

    return ResultPackageData.fromJson(
      (json['resultPackage'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<ResultSendLog> sendTeacherResultPackage({
    required String token,
    required String resultPackageId,
    required List<String> recipients,
    required bool sendInApp,
    required bool sendEmail,
    String screenshotUrl = '',
  }) async {
    final json = await _requestJson(
      'POST',
      '/teacher/results/$resultPackageId/send',
      token: token,
      body: {
        'recipients': recipients,
        'channels': {'inApp': sendInApp, 'email': sendEmail},
        if (screenshotUrl.trim().isNotEmpty) 'screenshotUrl': screenshotUrl,
      },
    );

    return ResultSendLog.fromJson(
      (json['sendLog'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    );
  }

  Future<ResultScreenshotUploadData> uploadTeacherResultScreenshot({
    required String token,
    required String resultPackageId,
    required List<int> fileBytes,
    String fileName = 'result-report.png',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiConfig.baseUrl}/teacher/results/$resultPackageId/screenshot',
      ),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'screenshotFile',
        fileBytes,
        filename: fileName,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw FocusMissionApiException(
        (json['message'] ?? 'Screenshot upload failed.').toString(),
      );
    }

    final screenshot =
        (json['screenshot'] as Map<dynamic, dynamic>? ?? const {})
            .cast<String, dynamic>();
    return ResultScreenshotUploadData.fromJson(screenshot);
  }

  String resolveApiUrl(String relativePath) {
    final rawPath = relativePath.trim();
    if (rawPath.isEmpty) {
      return '';
    }
    if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
      return rawPath;
    }

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    return Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: rawPath,
    ).toString();
  }

  Future<CompleteMissionResult> completeStudentMission({
    required String token,
    required String studentId,
    required String subjectId,
    required String sessionType,
    String? missionId,
    required int focusScore,
    int? correctAnswers,
    required int completedQuestions,
    required String behaviourStatus,
    required String notes,
    String? startTime,
    String? submitTime,
    Map<String, dynamic>? resultEvidence,
    int xpAwarded = 20,
  }) async {
    final json = await _requestJson(
      'POST',
      '/student/session/complete',
      token: token,
      body: {
        'studentId': studentId,
        'subjectId': subjectId,
        'sessionType': sessionType,
        if (missionId != null && missionId.isNotEmpty) 'missionId': missionId,
        'focusScore': focusScore,
        ...?correctAnswers == null ? null : {'correctAnswers': correctAnswers},
        'completedQuestions': completedQuestions,
        'behaviourStatus': behaviourStatus,
        'notes': notes,
        ...?startTime == null ? null : {'startTime': startTime},
        ...?submitTime == null ? null : {'submitTime': submitTime},
        ...?resultEvidence == null ? null : {'resultEvidence': resultEvidence},
        'xpAwarded': xpAwarded,
      },
    );

    return CompleteMissionResult.fromJson(json);
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    late final http.Response response;

    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
      case 'POST':
        response = await _client.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        );
      case 'PATCH':
        response = await _client.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        );
      case 'DELETE':
        response = await _client.delete(uri, headers: headers);
      default:
        throw UnsupportedError('Unsupported method: $method');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw FocusMissionApiException(
        (json['message'] ?? 'Request failed.').toString(),
      );
    }

    return json;
  }

  Future<List<dynamic>> _requestList(
    String method,
    String path, {
    String? token,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    late final http.Response response;

    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
      default:
        throw UnsupportedError('Unsupported method: $method');
    }

    final decoded = jsonDecode(response.body);

    if (response.statusCode >= 400) {
      if (decoded is Map<String, dynamic>) {
        throw FocusMissionApiException(
          (decoded['message'] ?? 'Request failed.').toString(),
        );
      }
      throw const FocusMissionApiException('Request failed.');
    }

    if (decoded is! List<dynamic>) {
      throw const FocusMissionApiException('Unexpected list response.');
    }

    return decoded;
  }

  String _buildDateRangeQuery({String? from, String? to}) {
    final params = <String, String>{
      if (from != null && from.trim().isNotEmpty) 'from': from.trim(),
      if (to != null && to.trim().isNotEmpty) 'to': to.trim(),
    };
    if (params.isEmpty) {
      return '';
    }
    return '?${Uri(queryParameters: params).query}';
  }
}

class FocusMissionApiException implements Exception {
  const FocusMissionApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
