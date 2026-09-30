/**
 * WHAT: Formats mission names from their structured identity.
 * WHY: Every role must distinguish Objective, Theory and Essay without guessing
 * from question counts or sessions, while retaining teacher-authored names.
 * HOW: Replace only generic defaults and the narrow canonical generated syntax.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

String missionTypeLabel(String type) => switch (type.trim().toUpperCase()) {
  'QUESTIONS' || 'OBJECTIVE' => 'Objective',
  'THEORY' => 'Theory',
  'ESSAY_BUILDER' || 'ESSAY' => 'Essay',
  _ => '',
};

bool isGeneratedMissionTitle(String title, {String subject = ''}) {
  final value = title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  final subjectName = subject
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
  const defaults = [
    '',
    'mission',
    'morning mission',
    'afternoon mission',
    'practice mission',
  ];
  if (defaults.contains(value)) return true;
  if (subjectName.isNotEmpty &&
      defaults.skip(1).any((suffix) => value == '$subjectName $suffix')) {
    return true;
  }
  // Canonical generated titles must follow edits to type, task focus and count.
  // No type is inferred from this match; classification uses the supplied field.
  return RegExp(
    r'^(?:(?:[pmd]\d+)(?: \+ [pmd]\d+)* )?(?:objective q\d+|theory q\d+|essay)$',
  ).hasMatch(value);
}

String missionDisplayName({
  required String title,
  required String type,
  Iterable<String> taskCodes = const [],
  int? questionCount,
  String subject = '',
}) {
  final label = missionTypeLabel(type);
  if (label.isEmpty || !isGeneratedMissionTitle(title, subject: subject)) {
    return title.trim().isEmpty ? 'Mission' : title.trim();
  }
  final codes = taskCodes
      .map((code) => code.trim().toUpperCase())
      .where((code) => code.isNotEmpty)
      .toSet();
  return [
    if (codes.isNotEmpty) codes.join(' + '),
    label,
    if (label != 'Essay' && questionCount != null && questionCount > 0)
      'Q$questionCount',
  ].join(' ');
}
