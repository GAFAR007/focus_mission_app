/**
 * WHAT:
 * standalone_paper_models defines typed teacher-side DTOs for standalone Test
 * and Exam draft authoring.
 * WHY:
 * Standalone papers are intentionally separate from missions, so the frontend
 * needs dedicated models instead of overloading MissionPayload.
 * HOW:
 * Parse backend JSON into immutable paper, item, and import-readiness models
 * that standalone paper screens can edit and render safely.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

class StandalonePaperSubjectSummary {
  const StandalonePaperSubjectSummary({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String icon;
  final String color;

  factory StandalonePaperSubjectSummary.fromJson(Map<String, dynamic> json) {
    return StandalonePaperSubjectSummary(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
    );
  }
}

class StandalonePaperItem {
  const StandalonePaperItem({
    required this.itemType,
    required this.learningText,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.expectedAnswer,
    required this.acceptedAnswers,
    required this.explanation,
    required this.minWordCount,
  });

  final String itemType;
  final String learningText;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String expectedAnswer;
  final List<String> acceptedAnswers;
  final String explanation;
  final int minWordCount;

  factory StandalonePaperItem.fromJson(Map<String, dynamic> json) {
    return StandalonePaperItem(
      itemType: (json['itemType'] ?? '').toString(),
      learningText: (json['learningText'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      options: _asStringList(json['options']),
      correctIndex: _asInt(json['correctIndex'], fallback: -1),
      expectedAnswer: (json['expectedAnswer'] ?? '').toString(),
      acceptedAnswers: _asStringList(json['acceptedAnswers']),
      explanation: (json['explanation'] ?? '').toString(),
      minWordCount: _asInt(json['minWordCount']),
    );
  }

  StandalonePaperItem copyWith({
    String? itemType,
    String? learningText,
    String? prompt,
    List<String>? options,
    int? correctIndex,
    String? expectedAnswer,
    List<String>? acceptedAnswers,
    String? explanation,
    int? minWordCount,
  }) {
    return StandalonePaperItem(
      itemType: itemType ?? this.itemType,
      learningText: learningText ?? this.learningText,
      prompt: prompt ?? this.prompt,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      expectedAnswer: expectedAnswer ?? this.expectedAnswer,
      acceptedAnswers: acceptedAnswers ?? this.acceptedAnswers,
      explanation: explanation ?? this.explanation,
      minWordCount: minWordCount ?? this.minWordCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemType': itemType,
      'learningText': learningText,
      'prompt': prompt,
      'options': options,
      'correctIndex': correctIndex,
      'expectedAnswer': expectedAnswer,
      'acceptedAnswers': acceptedAnswers,
      'explanation': explanation,
      'minWordCount': minWordCount,
    };
  }
}

class StandalonePaperDraft {
  const StandalonePaperDraft({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.paperKind,
    required this.title,
    required this.teacherNote,
    required this.sourceUnitText,
    required this.sourceRawText,
    required this.sourceFileName,
    required this.sourceFileType,
    required this.status,
    required this.targetDate,
    required this.durationMinutes,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.itemCount,
    required this.items,
    this.subject,
  });

  final String id;
  final String teacherId;
  final String studentId;
  final String paperKind;
  final String title;
  final String teacherNote;
  final String sourceUnitText;
  final String sourceRawText;
  final String sourceFileName;
  final String sourceFileType;
  final String status;
  final String targetDate;
  final int durationMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final int itemCount;
  final List<StandalonePaperItem> items;
  final StandalonePaperSubjectSummary? subject;

  bool get isDraft => status.trim().toLowerCase() == 'draft';

  factory StandalonePaperDraft.fromJson(Map<String, dynamic> json) {
    return StandalonePaperDraft(
      id: (json['id'] ?? '').toString(),
      teacherId: (json['teacherId'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      paperKind: (json['paperKind'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      teacherNote: (json['teacherNote'] ?? '').toString(),
      sourceUnitText: (json['sourceUnitText'] ?? '').toString(),
      sourceRawText: (json['sourceRawText'] ?? '').toString(),
      sourceFileName: (json['sourceFileName'] ?? '').toString(),
      sourceFileType: (json['sourceFileType'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      targetDate: (json['targetDate'] ?? '').toString(),
      durationMinutes: _asInt(json['durationMinutes']),
      createdAt: _asDateTime(json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt']),
      publishedAt: _asDateTime(json['publishedAt']),
      itemCount: _asInt(json['itemCount']),
      items: _asList(json['items'])
          .map((item) => StandalonePaperItem.fromJson(_asMap(item)))
          .toList(growable: false),
      subject: _asNullableMap(json['subject']) == null
          ? null
          : StandalonePaperSubjectSummary.fromJson(_asMap(json['subject'])),
    );
  }

  StandalonePaperDraft copyWith({
    String? id,
    String? teacherId,
    String? studentId,
    String? paperKind,
    String? title,
    String? teacherNote,
    String? sourceUnitText,
    String? sourceRawText,
    String? sourceFileName,
    String? sourceFileType,
    String? status,
    String? targetDate,
    int? durationMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    int? itemCount,
    List<StandalonePaperItem>? items,
    StandalonePaperSubjectSummary? subject,
  }) {
    return StandalonePaperDraft(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      paperKind: paperKind ?? this.paperKind,
      title: title ?? this.title,
      teacherNote: teacherNote ?? this.teacherNote,
      sourceUnitText: sourceUnitText ?? this.sourceUnitText,
      sourceRawText: sourceRawText ?? this.sourceRawText,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      sourceFileType: sourceFileType ?? this.sourceFileType,
      status: status ?? this.status,
      targetDate: targetDate ?? this.targetDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      itemCount: itemCount ?? this.itemCount,
      items: items ?? this.items,
      subject: subject ?? this.subject,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacherId': teacherId,
      'studentId': studentId,
      'paperKind': paperKind,
      'title': title,
      'teacherNote': teacherNote,
      'sourceUnitText': sourceUnitText,
      'sourceRawText': sourceRawText,
      'sourceFileName': sourceFileName,
      'sourceFileType': sourceFileType,
      'status': status,
      'targetDate': targetDate,
      'durationMinutes': durationMinutes,
      'itemCount': itemCount,
      'items': items.map((item) => item.toJson()).toList(growable: false),
    };
  }
}

class StandalonePaperImportReadiness {
  const StandalonePaperImportReadiness({
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

  factory StandalonePaperImportReadiness.fromJson(Map<String, dynamic> json) {
    return StandalonePaperImportReadiness(
      status: (json['status'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      detectedSignals: _asStringList(json['detectedSignals']),
      missingRequirements: _asStringList(json['missingRequirements']),
      warningNotes: _asStringList(json['warningNotes']),
    );
  }
}

class UploadedStandalonePaperDraft {
  const UploadedStandalonePaperDraft({
    required this.fileName,
    required this.mimeType,
    required this.sourceKind,
    required this.extractedText,
    required this.extractedCharacterCount,
    required this.draftReadiness,
    this.prefilledPaper,
  });

  final String fileName;
  final String mimeType;
  final String sourceKind;
  final String extractedText;
  final int extractedCharacterCount;
  final StandalonePaperImportReadiness draftReadiness;
  final StandalonePaperDraft? prefilledPaper;

  factory UploadedStandalonePaperDraft.fromJson(Map<String, dynamic> json) {
    return UploadedStandalonePaperDraft(
      fileName: (json['fileName'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      sourceKind: (json['sourceKind'] ?? '').toString(),
      extractedText: (json['extractedText'] ?? '').toString(),
      extractedCharacterCount: _asInt(json['extractedCharacterCount']),
      draftReadiness: StandalonePaperImportReadiness.fromJson(
        _asMap(json['draftReadiness']),
      ),
      prefilledPaper: _asNullableMap(json['prefilledPaper']) == null
          ? null
          : StandalonePaperDraft.fromJson(_asMap(json['prefilledPaper'])),
    );
  }
}

List<dynamic> _asList(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }
  return const <dynamic>[];
}

List<String> _asStringList(dynamic value) {
  return _asList(value).map((item) => item.toString()).toList(growable: false);
}

Map<String, dynamic> _asMap(dynamic value) {
  return (value as Map<dynamic, dynamic>? ?? const {}).cast<String, dynamic>();
}

Map<String, dynamic>? _asNullableMap(dynamic value) {
  if (value is Map<dynamic, dynamic>) {
    return value.cast<String, dynamic>();
  }
  return null;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _asDateTime(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}
