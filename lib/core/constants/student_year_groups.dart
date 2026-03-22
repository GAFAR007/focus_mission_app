/*
 * WHAT:
 * Shared year-group options for student creation, profile display, and paper
 * targeting flows.
 * WHY:
 * Teachers and management need one consistent list so year-based selection for
 * tests and exams never drifts across screens.
 * HOW:
 * Expose a single ordered list that UI dropdowns and filters can reuse.
 */

const List<String> kStudentYearGroupOptions = <String>[
  'Year 1',
  'Year 2',
  'Year 3',
  'Year 4',
  'Year 5',
  'Year 6',
  'Year 7',
  'Year 8',
  'Year 9',
  'Year 10',
  'Year 11',
  'Year 12',
  'Year 13',
];
