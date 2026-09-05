/**
 * WHAT:
 * Defines the qualification Task Focus codes available to teacher workflows.
 * WHY:
 * Mission authoring, certification setup, and pathway filtering must use the
 * same ordered code list so P1/P2 labels cannot drift between screens.
 * HOW:
 * Expose one immutable presentation-order list for teacher-facing controls.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

const List<String> kTaskFocusCodes = <String>[
  'P1',
  'P2',
  'P3',
  'P4',
  'P5',
  'P6',
  'P7',
  'M1',
  'M2',
  'M3',
  'D1',
  'D2',
];
