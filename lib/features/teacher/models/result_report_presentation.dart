/**
 * WHAT:
 * Shared presentation mapping and HTML generation for teacher result reports.
 * WHY:
 * View Result and saved-history Download Result must interpret student answers,
 * duration, labels, colours, and immutable result-package evidence identically.
 * HOW:
 * Normalize report metadata and objective answer states once, expose shared
 * visual tokens, and build downloadable HTML from the same normalized values.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../shared/models/focus_mission_models.dart';

class ResultReportVisualTokens {
  const ResultReportVisualTokens._();

  static const Color navy = Color(0xFF1F315D);
  static const Color muted = Color(0xFF68789C);
  static const Color neutralSurface = Color(0xFFF5F7FB);
  static const Color neutralBorder = Color(0xFFDCE3ED);
  static const Color success = Color(0xFF217A47);
  static const Color successSurface = Color(0xFFEAF7EE);
  static const Color successBorder = Color(0xFF72B98A);
  static const Color warning = Color(0xFF9A4E0B);
  static const Color warningSurface = Color(0xFFFFF1DF);
  static const Color warningBorder = Color(0xFFD58A43);
  static const Color accent = Color(0xFF3156D3);

  static String css(Color color) {
    final value = color.toARGB32();
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

String formatResultDuration(int rawSeconds) {
  // WHY: Duration remains stored as seconds for audit accuracy, but raw values
  // are converted at the presentation boundary for staff readability.
  final seconds = rawSeconds < 0 ? 0 : rawSeconds;
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '$minutes min $remainingSeconds sec';
}

String resultStudentName(String packageName, {String fallback = 'Student'}) {
  final resolved = packageName.trim().isNotEmpty
      ? packageName.trim()
      : fallback.trim();
  return resolved.isEmpty ? 'Student' : resolved;
}

String resultStudentFirstName(String studentName) {
  final resolved = resultStudentName(studentName);
  return resolved.split(RegExp(r'\s+')).first;
}

String resultPossessiveName(String name) {
  final resolved = resultStudentName(name);
  return resolved.toLowerCase().endsWith('s') ? "$resolved'" : "$resolved's";
}

String resultStudentAnswerHeading(String studentName) {
  return '${resultPossessiveName(studentName)} answer'.toUpperCase();
}

String resultCompactAnswerLabel(String studentName, {required bool isCorrect}) {
  final label =
      '${resultPossessiveName(resultStudentFirstName(studentName))} answer';
  return isCorrect ? '$label • Correct' : label;
}

enum ResultOptionVisualState {
  neutral,
  studentIncorrect,
  correct,
  studentCorrect,
}

class ResultObjectiveQuestionPresentation {
  const ResultObjectiveQuestionPresentation({
    required this.studentName,
    required this.questionText,
    required this.options,
    required this.selectedLetter,
    required this.selectedAnswer,
    required this.correctLetter,
    required this.correctAnswer,
    required this.correctness,
    required this.pointsEarned,
    required this.maxPoints,
    required this.legacySelectionUnavailable,
  });

  factory ResultObjectiveQuestionPresentation.fromEvidence(
    Map<String, dynamic> question, {
    required String studentName,
  }) {
    final selectedLetter = (question['selectedOptionLetter'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final selectedAnswer = (question['selectedAnswer'] ?? '').toString().trim();
    final correctLetter = (question['correctOptionLetter'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final correctAnswer = (question['correctAnswer'] ?? '').toString().trim();
    final correctness = question['correctness'] == true;
    final storedMaxPoints = _asInt(question['maxPoints']);
    final maxPoints = storedMaxPoints > 0 ? storedMaxPoints : 1;
    final pointsEarned = storedMaxPoints > 0
        ? _asInt(question['pointsEarned'])
        : (correctness ? 1 : 0);

    return ResultObjectiveQuestionPresentation(
      studentName: resultStudentName(studentName),
      questionText: (question['questionText'] ?? '').toString().trim(),
      options: _extractQuestionOptions(question),
      selectedLetter: selectedLetter,
      selectedAnswer: selectedAnswer,
      correctLetter: correctLetter,
      correctAnswer: correctAnswer,
      correctness: correctness,
      pointsEarned: pointsEarned,
      maxPoints: maxPoints,
      legacySelectionUnavailable:
          question['legacySelectionUnavailable'] == true,
    );
  }

  final String studentName;
  final String questionText;
  final Map<String, String> options;
  final String selectedLetter;
  final String selectedAnswer;
  final String correctLetter;
  final String correctAnswer;
  final bool correctness;
  final int pointsEarned;
  final int maxPoints;
  final bool legacySelectionUnavailable;

  bool get hasMeaningfulOptions =>
      options.values.any((value) => value.isNotEmpty);

  ResultOptionVisualState stateFor(String letter) {
    final isStudentAnswer = letter == selectedLetter;
    final isCorrectAnswer = letter == correctLetter;
    if (isStudentAnswer && isCorrectAnswer) {
      return ResultOptionVisualState.studentCorrect;
    }
    if (isStudentAnswer) {
      return ResultOptionVisualState.studentIncorrect;
    }
    if (isCorrectAnswer) {
      return ResultOptionVisualState.correct;
    }
    return ResultOptionVisualState.neutral;
  }

  String optionTag(String letter) {
    return switch (stateFor(letter)) {
      ResultOptionVisualState.studentCorrect => resultCompactAnswerLabel(
        studentName,
        isCorrect: true,
      ),
      ResultOptionVisualState.studentIncorrect => resultCompactAnswerLabel(
        studentName,
        isCorrect: false,
      ),
      ResultOptionVisualState.correct => 'Correct answer',
      ResultOptionVisualState.neutral => '',
    };
  }

  String get selectedAnswerValue {
    final prefix = selectedLetter.isEmpty ? '' : '$selectedLetter) ';
    final answer = selectedAnswer.isEmpty
        ? 'No answer recorded'
        : selectedAnswer;
    return '$prefix$answer';
  }

  String get correctAnswerValue {
    final prefix = correctLetter.isEmpty ? '' : '$correctLetter) ';
    return '$prefix${correctAnswer.isEmpty ? 'No correct answer recorded' : correctAnswer}';
  }
}

class TeacherResultReportEntry {
  const TeacherResultReportEntry({
    required this.result,
    required this.resultPackage,
  });

  final ResultHistoryItem result;
  final ResultPackageData resultPackage;
}

class TeacherResultReportHtmlBuilder {
  const TeacherResultReportHtmlBuilder();

  String build({
    required String studentName,
    required List<TeacherResultReportEntry> entries,
    required String summaryLabel,
  }) {
    final resolvedStudentName = resultStudentName(studentName);
    final sortedEntries = [...entries]
      ..sort((left, right) => _entryDate(right).compareTo(_entryDate(left)));
    final title = entries.length == 1
        ? entries.first.resultPackage.meta.missionTitle
        : '$resolvedStudentName Results';
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en"><head><meta charset="utf-8" />')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1" />',
      )
      ..writeln('<title>${_escape('$title - Result Report')}</title>')
      ..writeln('<style>${_styles()}</style></head><body>')
      ..writeln('<main class="page">')
      ..writeln('<header class="report-header">')
      ..writeln('<span class="eyebrow">STUDENT RESULT REPORT</span>')
      ..writeln('<h1>${_escape(title)}</h1>')
      ..writeln(
        '<p>${_escape(resolvedStudentName)} · ${_escape(summaryLabel)}</p>',
      )
      ..writeln('</header>');

    for (final entry in sortedEntries) {
      buffer.writeln(
        _entryHtml(entry, fallbackStudentName: resolvedStudentName),
      );
    }

    buffer.writeln('</main></body></html>');
    return buffer.toString();
  }

  String _entryHtml(
    TeacherResultReportEntry entry, {
    required String fallbackStudentName,
  }) {
    final result = entry.result;
    final package = entry.resultPackage;
    final meta = package.meta;
    final studentName = resultStudentName(
      meta.studentName,
      fallback: fallbackStudentName,
    );
    final evidence = package.evidence;
    final isTheory = package.missionType == 'THEORY';
    final isManualTeacherResult = evidence['manualTeacherResult'] == true;
    final teacherReviewStatus = (evidence['teacherReviewStatus'] ?? 'pending')
        .toString()
        .trim();
    final reviewStatus = (evidence['reviewStatus'] ?? 'pending_review')
        .toString()
        .trim();
    final theoryAverage = _asDouble(evidence['averageTeacherScorePercent']);
    final theoryXpMax = _asInt(evidence['xpMax']);
    final safeTheoryXpMax = theoryXpMax <= 0 ? 50 : theoryXpMax;
    final score = isTheory
        ? reviewStatus == 'scored'
              ? 'Average: ${_formatOneDecimal(theoryAverage)}%'
              : 'Score: Pending review'
        : isManualTeacherResult && teacherReviewStatus != 'scored'
        ? 'Score: Pending review'
        : 'Score: ${meta.scoreCorrect}/${meta.scoreTotal} (${meta.scorePercent}%)';
    final xpLabel = isTheory
        ? reviewStatus == 'scored'
              ? 'XP: ${meta.xpAwarded}/$safeTheoryXpMax'
              : 'XP: Pending'
        : isManualTeacherResult && teacherReviewStatus != 'scored'
        ? 'XP: Pending'
        : 'XP: ${meta.xpAwarded}';
    final triesToComplete = _asInt(
      evidence['triesToComplete'] ?? evidence['completionAttemptNumber'],
    );
    final taskFocus = meta.taskCodes.isEmpty
        ? 'None'
        : meta.taskCodes.join(', ');
    final session = result.sessionType.trim().isEmpty
        ? 'Not recorded'
        : _titleCase(result.sessionType);

    return '''
<article class="report-card">
  <div class="title-row">
    <div><span class="eyebrow">${_escape(_formatLabel(entry))}</span><h2>${_escape(meta.missionTitle)}</h2></div>
    <div class="score"><strong>${_escape(score)}</strong><span>${_escape(xpLabel)}</span></div>
  </div>
  <div class="status-grid">
    ${_meta('Type', package.resultKind == 'paper_assessment' ? 'Paper assessment' : package.missionType)}
    ${isTheory || isManualTeacherResult ? _meta('Review', isTheory ? (reviewStatus == 'scored' ? 'Scored' : 'Pending review') : (teacherReviewStatus == 'scored' ? 'Scored' : 'Pending review')) : ''}
    ${_meta('Send', package.latestSendStatus)}
    ${_meta('Tries', '${triesToComplete <= 0 ? 1 : triesToComplete}')}
  </div>
  <div class="meta-grid">
    ${_meta('Student', studentName)}
    ${_meta('Subject', meta.subject.trim().isEmpty ? (result.subject?.name ?? 'Not recorded') : meta.subject)}
    ${_meta('Task focus', taskFocus)}
    ${_meta('Session', session)}
    ${_meta('Assigned date', meta.assignedDate.trim().isEmpty ? _entryDate(entry) : meta.assignedDate)}
    ${_meta('Started', _formatDateTime(meta.startTime))}
    ${_meta('Submitted', _formatDateTime(meta.submitTime))}
    ${_meta('Duration', formatResultDuration(meta.durationSeconds))}
  </div>
  ${_evidenceHtml(entry, studentName: studentName)}
</article>
''';
  }

  String _evidenceHtml(
    TeacherResultReportEntry entry, {
    required String studentName,
  }) {
    final evidence = entry.resultPackage.evidence;
    final format = (evidence['format'] ?? entry.result.draftFormat)
        .toString()
        .trim()
        .toUpperCase();
    if (format == 'THEORY') {
      return _theoryHtml(evidence, studentName: studentName);
    }
    if (format == 'ESSAY_BUILDER') {
      return _essayHtml(evidence, studentName: studentName);
    }
    return _questionsHtml(evidence, studentName: studentName);
  }

  String _questionsHtml(
    Map<String, dynamic> evidence, {
    required String studentName,
  }) {
    final questions = evidence['questions'] as List<dynamic>? ?? const [];
    if (questions.isEmpty) {
      return '<section class="evidence"><h3>Question evidence</h3><p class="muted">No question evidence saved.</p></section>';
    }
    final buffer = StringBuffer(
      '<section class="evidence"><h3>Question evidence</h3>',
    );
    for (final entry in questions.asMap().entries) {
      final question = (entry.value as Map<dynamic, dynamic>)
          .cast<String, dynamic>();
      final itemType = (question['itemType'] ?? '').toString().toUpperCase();
      if (itemType == 'FILL_GAP') {
        buffer.writeln(
          _writtenQuestionHtml(
            entry.key + 1,
            question,
            studentName: studentName,
            expectedKey: 'expectedAnswer',
          ),
        );
        continue;
      }
      if (itemType == 'THEORY') {
        buffer.writeln(
          _writtenQuestionHtml(
            entry.key + 1,
            question,
            studentName: studentName,
            expectedKey: 'expectedAnswer',
          ),
        );
        continue;
      }
      final view = ResultObjectiveQuestionPresentation.fromEvidence(
        question,
        studentName: studentName,
      );
      buffer
        ..writeln(
          '<section class="question ${view.correctness ? 'is-correct' : 'is-incorrect'}">',
        )
        ..writeln(
          '<div class="question-head"><strong>Question ${entry.key + 1}</strong><span>${view.correctness ? 'Correct' : 'Incorrect'} · ${view.pointsEarned}/${view.maxPoints}</span></div>',
        )
        ..writeln('<p class="prompt">${_escape(view.questionText)}</p>');
      if (view.hasMeaningfulOptions) {
        buffer.writeln('<div class="options">');
        for (final letter in ['A', 'B', 'C', 'D']) {
          final state = view.stateFor(letter);
          final stateClass = switch (state) {
            ResultOptionVisualState.studentCorrect => 'student-correct',
            ResultOptionVisualState.studentIncorrect => 'student-incorrect',
            ResultOptionVisualState.correct => 'correct-answer',
            ResultOptionVisualState.neutral => '',
          };
          final tag = view.optionTag(letter);
          buffer.writeln(
            '<div class="option $stateClass"><span class="letter">$letter</span><span class="option-text">${_escape(view.options[letter] ?? '')}</span>${tag.isEmpty ? '' : '<span class="answer-tag">${_escape(tag)}</span>'}</div>',
          );
        }
        buffer.writeln('</div>');
      } else {
        buffer.writeln(
          _answerComparisonHtml(
            studentName: studentName,
            studentAnswer: view.selectedAnswerValue,
            correctAnswer: view.correctAnswerValue,
            isCorrect: view.correctness,
          ),
        );
      }
      if (view.legacySelectionUnavailable &&
          view.selectedLetter.isEmpty &&
          view.selectedAnswer.isEmpty) {
        buffer.writeln(
          '<p class="muted">Original answer selection was not saved in this older record.</p>',
        );
      }
      buffer.writeln('</section>');
    }
    buffer.writeln('</section>');
    return buffer.toString();
  }

  String _theoryHtml(
    Map<String, dynamic> evidence, {
    required String studentName,
  }) {
    final questions = evidence['questions'] as List<dynamic>? ?? const [];
    final buffer = StringBuffer(
      '<section class="evidence"><h3>Theory evidence</h3>',
    );
    for (final entry in questions.asMap().entries) {
      final question = (entry.value as Map<dynamic, dynamic>)
          .cast<String, dynamic>();
      buffer.writeln(
        _writtenQuestionHtml(
          entry.key + 1,
          question,
          studentName: studentName,
          expectedKey: 'expectedAnswer',
        ),
      );
    }
    buffer.writeln('</section>');
    return buffer.toString();
  }

  String _writtenQuestionHtml(
    int index,
    Map<String, dynamic> question, {
    required String studentName,
    required String expectedKey,
  }) {
    final studentAnswer = (question['studentAnswer'] ?? '').toString().trim();
    final expectedAnswer = (question[expectedKey] ?? '').toString().trim();
    final feedback = (question['teacherFeedback'] ?? '').toString().trim();
    return '''
<section class="question">
  <div class="question-head"><strong>Question $index</strong></div>
  <p class="prompt">${_escape((question['questionText'] ?? '').toString())}</p>
  <div class="answer-box student"><span>${_escape(resultStudentAnswerHeading(studentName))}</span><p>${_safeLinks(studentAnswer.isEmpty ? 'No answer recorded.' : studentAnswer)}</p></div>
  ${expectedAnswer.isEmpty ? '' : '<div class="answer-box correct"><span>CORRECT ANSWER</span><p>${_escape(expectedAnswer)}</p></div>'}
  ${feedback.isEmpty ? '' : '<div class="feedback"><strong>Teacher feedback</strong><p>${_escape(feedback)}</p></div>'}
</section>
''';
  }

  String _essayHtml(
    Map<String, dynamic> evidence, {
    required String studentName,
  }) {
    final sentences = evidence['perSentence'] as List<dynamic>? ?? const [];
    final finalEssay = (evidence['finalEssayText'] ?? '').toString().trim();
    final buffer = StringBuffer(
      '<section class="evidence"><h3>Essay evidence</h3>',
    );
    for (final entry in sentences.asMap().entries) {
      final sentence = (entry.value as Map<dynamic, dynamic>)
          .cast<String, dynamic>();
      final blanks = sentence['blankSelections'] as List<dynamic>? ?? const [];
      buffer
        ..writeln('<section class="question">')
        ..writeln(
          '<div class="question-head"><strong>Sentence ${entry.key + 1}</strong><span>${_escape((sentence['role'] ?? 'Detail').toString())}</span></div>',
        );
      for (final blank in blanks) {
        final item = (blank as Map<dynamic, dynamic>).cast<String, dynamic>();
        final selected = (item['chosenOptionText'] ?? '').toString().trim();
        final correct = (item['correctOptionText'] ?? '').toString().trim();
        final isCorrect = selected.isNotEmpty && selected == correct;
        buffer.writeln(
          _answerComparisonHtml(
            studentName: studentName,
            studentAnswer: selected.isEmpty ? 'No answer recorded' : selected,
            correctAnswer: correct.isEmpty
                ? 'No correct answer recorded'
                : correct,
            isCorrect: isCorrect,
          ),
        );
      }
      buffer.writeln('</section>');
    }
    if (finalEssay.isNotEmpty) {
      buffer.writeln(
        '<section class="question"><div class="answer-box student"><span>${_escape(resultStudentAnswerHeading(studentName))}</span><p>${_safeLinks(finalEssay)}</p></div></section>',
      );
    }
    buffer.writeln('</section>');
    return buffer.toString();
  }

  String _answerComparisonHtml({
    required String studentName,
    required String studentAnswer,
    required String correctAnswer,
    required bool isCorrect,
  }) {
    return '<div class="answer-grid"><div class="answer-box ${isCorrect ? 'correct' : 'student-incorrect'}"><span>${_escape(resultStudentAnswerHeading(studentName))}${isCorrect ? ' · CORRECT' : ''}</span><p>${_escape(studentAnswer)}</p></div>${isCorrect ? '' : '<div class="answer-box correct"><span>CORRECT ANSWER</span><p>${_escape(correctAnswer)}</p></div>'}</div>';
  }

  String _meta(String label, String value) {
    return '<div class="meta"><span>${_escape(label)}</span><strong>${_escape(value)}</strong></div>';
  }

  String _entryDate(TeacherResultReportEntry entry) {
    final metaDate = entry.resultPackage.meta.assignedDate.trim();
    if (metaDate.isNotEmpty) return metaDate;
    return _formatDate(
      entry.result.availableOnDate ??
          entry.result.publishedAt ??
          entry.result.createdAt,
    );
  }

  String _formatLabel(TeacherResultReportEntry entry) {
    if (entry.result.isPaperAssessment) return 'Paper assessment';
    return switch (entry.result.draftFormat.trim().toUpperCase()) {
      'THEORY' => 'Theory',
      'ESSAY_BUILDER' => 'Essay Builder',
      _ => '${entry.result.questionCount} questions',
    };
  }

  String _styles() {
    final navy = ResultReportVisualTokens.css(ResultReportVisualTokens.navy);
    final muted = ResultReportVisualTokens.css(ResultReportVisualTokens.muted);
    final neutral = ResultReportVisualTokens.css(
      ResultReportVisualTokens.neutralSurface,
    );
    final border = ResultReportVisualTokens.css(
      ResultReportVisualTokens.neutralBorder,
    );
    final accent = ResultReportVisualTokens.css(
      ResultReportVisualTokens.accent,
    );
    final success = ResultReportVisualTokens.css(
      ResultReportVisualTokens.success,
    );
    final successSurface = ResultReportVisualTokens.css(
      ResultReportVisualTokens.successSurface,
    );
    final successBorder = ResultReportVisualTokens.css(
      ResultReportVisualTokens.successBorder,
    );
    final warning = ResultReportVisualTokens.css(
      ResultReportVisualTokens.warning,
    );
    final warningSurface = ResultReportVisualTokens.css(
      ResultReportVisualTokens.warningSurface,
    );
    final warningBorder = ResultReportVisualTokens.css(
      ResultReportVisualTokens.warningBorder,
    );
    return '''
* { box-sizing: border-box; }
body { margin: 0; font-family: Inter, Arial, sans-serif; background: $neutral; color: $navy; }
.page { width: min(1020px, 100%); margin: 0 auto; padding: 32px 24px 56px; }
.report-header, .report-card { background: #FFFFFF; border: 1px solid $border; border-radius: 22px; }
.report-header { padding: 24px; margin-bottom: 18px; }
.report-header h1 { margin: 7px 0 5px; font-size: 28px; }
.report-header p, .muted { color: $muted; }
.eyebrow { color: $accent; font-size: 11px; font-weight: 800; letter-spacing: .09em; text-transform: uppercase; }
.report-card { padding: 22px; margin-bottom: 18px; }
.title-row { display: flex; justify-content: space-between; gap: 18px; align-items: flex-start; }
.title-row h2 { margin: 5px 0 0; font-size: 22px; }
.score { display: grid; gap: 3px; min-width: 135px; text-align: right; color: $accent; }
.score span { color: $muted; font-size: 13px; font-weight: 700; }
.meta-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 9px; margin: 18px 0; }
.status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 9px; margin: 18px 0 0; }
.meta { background: $neutral; border-radius: 12px; padding: 11px 12px; }
.meta span, .answer-box span { display: block; color: $muted; font-size: 10px; font-weight: 800; letter-spacing: .07em; text-transform: uppercase; }
.meta strong { display: block; margin-top: 4px; font-size: 13px; }
.evidence { border-top: 1px solid $border; padding-top: 18px; }
.evidence h3 { margin: 0 0 12px; font-size: 17px; }
.question { border: 1px solid $border; border-radius: 16px; padding: 15px; margin-bottom: 10px; background: #FFFFFF; }
.question.is-correct { border-left: 4px solid $success; }
.question.is-incorrect { border-left: 4px solid $warning; }
.question-head { display: flex; justify-content: space-between; gap: 12px; font-size: 13px; }
.question-head span { color: $muted; font-weight: 700; }
.prompt { font-weight: 700; line-height: 1.45; }
.options { display: grid; gap: 7px; }
.option { display: flex; align-items: center; gap: 9px; min-height: 42px; padding: 8px 10px; background: $neutral; border: 1px solid $border; border-radius: 11px; }
.letter { display: grid; place-items: center; min-width: 25px; height: 25px; border-radius: 7px; background: $navy; color: #FFFFFF; font-size: 11px; font-weight: 800; }
.option-text { flex: 1; font-size: 13px; }
.option.student-correct, .option.correct-answer { background: $successSurface; border-color: $successBorder; }
.option.student-incorrect { background: $warningSurface; border-color: $warningBorder; }
.answer-tag { color: $success; font-size: 11px; font-weight: 800; white-space: nowrap; }
.student-incorrect .answer-tag { color: $warning; }
.answer-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 8px; margin-top: 10px; }
.answer-box { border-radius: 12px; padding: 11px 12px; background: $neutral; border: 1px solid $border; }
.answer-box p { margin: 6px 0 0; line-height: 1.5; }
.answer-box.correct { background: $successSurface; border-color: $successBorder; }
.answer-box.correct span { color: $success; }
.answer-box.student-incorrect { background: $warningSurface; border-color: $warningBorder; }
.answer-box.student-incorrect span { color: $warning; }
.feedback { margin-top: 9px; padding: 10px 12px; border-radius: 12px; background: $neutral; }
.feedback p { margin: 5px 0 0; }
@media print { body { background: #FFFFFF; } .page { width: 100%; padding: 0; } .report-card, .question { break-inside: avoid; } }
@media (max-width: 620px) { .page { padding: 18px 12px 36px; } .title-row { flex-direction: column; } .score { text-align: left; } .option { align-items: flex-start; flex-wrap: wrap; } .answer-tag { width: 100%; margin-left: 34px; } }
''';
  }

  String _safeLinks(String value) {
    final pattern = RegExp(
      r'''(?:https?://|www\.)[^\s<>{}\[\]"']+''',
      caseSensitive: false,
    );
    final output = StringBuffer();
    var cursor = 0;
    for (final match in pattern.allMatches(value)) {
      output.write(_escape(value.substring(cursor, match.start)));
      final raw = match.group(0) ?? '';
      final href = raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw;
      final uri = Uri.tryParse(href);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        output.write(
          '<a href="${_escape(uri.toString())}" target="_blank" rel="noopener noreferrer">${_escape(raw)}</a>',
        );
      } else {
        output.write(_escape(raw));
      }
      cursor = match.end;
    }
    output.write(_escape(value.substring(cursor)));
    return output.toString();
  }

  String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) return 'No date';
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  String _formatDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return 'Not recorded';
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day $hour:$minute';
  }

  String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
  }
}

Map<String, String> _extractQuestionOptions(Map<String, dynamic> question) {
  final normalized = <String, String>{'A': '', 'B': '', 'C': '', 'D': ''};
  final rawOptions = question['options'];
  if (rawOptions is Map<dynamic, dynamic>) {
    for (final letter in normalized.keys) {
      normalized[letter] = (rawOptions[letter] ?? '').toString().trim();
    }
  }

  final selectedLetter = (question['selectedOptionLetter'] ?? '')
      .toString()
      .trim()
      .toUpperCase();
  final selectedAnswer = (question['selectedAnswer'] ?? '').toString().trim();
  final correctLetter = (question['correctOptionLetter'] ?? '')
      .toString()
      .trim()
      .toUpperCase();
  final correctAnswer = (question['correctAnswer'] ?? '').toString().trim();
  final remainingOptions =
      (question['remainingOptions'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);

  if (selectedLetter.isNotEmpty && normalized.containsKey(selectedLetter)) {
    normalized[selectedLetter] = normalized[selectedLetter]!.isNotEmpty
        ? normalized[selectedLetter]!
        : selectedAnswer;
  }
  if (correctLetter.isNotEmpty && normalized.containsKey(correctLetter)) {
    normalized[correctLetter] = normalized[correctLetter]!.isNotEmpty
        ? normalized[correctLetter]!
        : correctAnswer;
  }
  var remainingIndex = 0;
  for (final letter in normalized.keys) {
    if (normalized[letter]!.isNotEmpty ||
        remainingIndex >= remainingOptions.length) {
      continue;
    }
    normalized[letter] = remainingOptions[remainingIndex];
    remainingIndex += 1;
  }
  return normalized;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatOneDecimal(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}
