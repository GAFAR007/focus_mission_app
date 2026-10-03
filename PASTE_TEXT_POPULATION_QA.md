# Teacher Paste Text population — 3 October 2026

Implemented in the Developer Focus Mission frontend and sibling backend. No
MovieAnimator code, Pong changes, mentor changes, version metadata, academic
progression, permissions or deployment configuration was changed for this task.
No commit, push, tag or production deployment was performed.

## Workflow

The existing Populate objective / theory / essay actions now open one shared
source chooser with **Upload File** and **Paste Text**. The dedicated 10-question
assessment screen uses the same chooser.

Upload File retains the existing picker extensions, multipart upload, extraction,
strict validation and draft creation path. AI draft remains separate.

Paste Text encodes the teacher's text as a UTF-8 `pasted-assessment.txt` multipart
source and calls the existing `POST /teacher/ai/extract-source` endpoint with
`uploadMode=populate_draft` and `previewOnly=true`. Existing role, school, subject
and scheduled-lesson checks still execute. No Groq request is made.

The existing question, option, sentence and blank parsers return transient
`populationPreview.fields` alongside the existing readiness messages. These
fields are editable even when parsing is incomplete. The preview never creates a
Mission or consumes an assessment A/B slot. Missing options remain empty; missing
answers are not guessed. A teacher can repair fields and choose **Check edited
fields**, or amend the original pasted text to add missing sections. Fields are
serialized using the same supported import headings and checked again.

**Apply to builder** is enabled only after successful checking. It invokes the
existing normal import path. As before, importing a complete new source creates
a draft; importing onto an existing draft produces a review preview until Save.
Publishing remains a separate explicit teacher action. Student, subject, task
focus, date, session, format, difficulty and existing draft ID are passed through
the existing callers. Dedicated assessment mode still requires exactly 10
questions, hard difficulty and 50 XP, and retains assessment A/B policy.

Empty and whitespace input are rejected before an API request. Short, malformed,
wrong-format and partial content receive specific messages and retain readable
fields. Input is limited to 100,000 characters / 500 review fields. The preview
also reports the existing builder's 80-character Unit text save requirement.
Loading disables controls and duplicate submissions. A 45-second preview timeout
and network errors preserve the text and recognised fields for retry.

The shared parser also stops empty section labels swallowing the next label, and
stops Essay UNIT TEXT at the sentence/target headings. This keeps imported
teaching text separate from the guided sentence structure.

## Executed checks

| Check | Result |
| --- | --- |
| Existing frontend builder/assessment tests before edits | 31 passed |
| Existing backend Essay/assessment policy tests before edits | Passed |
| Final full Flutter suite | 254 passed |
| Final full backend suite, disposable loopback MongoDB replica set | 216 passed, 0 skipped |
| Focused dialog/builder/assessment suite | 42 passed |
| Flutter analysis | No issues found |
| Node syntax checks of changed service/routes | Passed |
| Both repository `git diff --check` checks | Passed |
| Release-mode Flutter Web build with isolated local API | Built |
| Dialog layouts | 390 px and 1440 px, Objective/Theory/Essay, no widget exceptions |

Backend regressions cover valid Objective/Theory/Essay, parity with file parsing,
editable-field round trips, missing title/options/prompt, partial essay blanks,
short/empty/oversized content, wrong type, the Unit text save requirement, teacher
ownership and preview write prevention. Frontend tests cover visible population,
editing/rechecking, failure retention, pending and duplicate taps, assessment
count checks, and unchanged file names/bytes through the picker path.

Evidence: `/tmp/focus-populate-qa/`, including `flutter-final.log`,
`backend-final.log`, `final-focused.log`, `analyze-final.log`,
`web-build-final.log`, `http-evidence.json`, and `saved-drafts.json`.

## Manual local checks

Only synthetic accounts in `population_visual_qa` on loopback MongoDB were used.
No production learner data was accessed or changed.

- Objective: pasted five questions with missing B/C/D options for question 1;
  observed the specific error and populated fields; repaired the three options,
  rechecked and applied into the existing five-question Review Draft.
- Essay: pasted structured sentence/blank content; observed title, Unit text,
  targets, learning bullets, preview and blank fields; applied into the existing
  guided essay preview with options and correct answer intact.
- Theory: pasted two questions, applied them, and saved the draft after correcting
  the short Unit text discovered during manual testing. The saved local draft has
  two questions, 130 characters of Unit text and the original P1 context.
- Assessment: pasted ten questions through the dedicated assessment screen;
  applied and saved P1 Assessment A, retaining ten questions and 50 XP. The local
  record retains `assessmentSequenceByTaskCode.P1 = A` and `status = draft`.
- Real authenticated multipart HTTP calls imported Objective TXT and DOCX,
  Theory PDF, and Essay TXT successfully through the existing endpoint. All
  preview calls left the mission count unchanged. These exercised the real
  extractors, authorization middleware and parser, not mocked service responses.
- The browser file chooser opened, but automated file selection was blocked by
  the Chrome extension's missing file-URL permission. A complete browser file
  upload is therefore **not claimed**. Picker regression tests and actual
  multipart API uploads passed. Scanned-image OCR was not manually retested.
- Browser acceptance covered the feature implementation; final client timeout,
  close-tap guard and source-label wording changes were additionally covered by
  the final analysis/widget suite. Local previews can retain an older Flutter
  service-worker build until all tabs for that origin close.

## Supported formats and limitations

This remains a deterministic structured-content importer, not a new AI parser.
Arbitrary paragraphs, tables, Markdown numbering or free-form exam papers cannot
reliably become complete assessments without the existing headings.

Objective: title, `UNIT TEXT`, numbered `Question N`, `Learn First`, `Prompt`,
`Options` containing A–D, and `Correct Answer`. Explanation remains optional.
Theory uses `Expected Answer` (or the existing Correct Answer fallback) and
optional `Minimum Word Count`; the existing 2–5 question constraint remains.

Essay Builder uses `Sentence N`, three or more `Learn First Bullet N` entries,
`Sentence Preview` with underscore blanks, and numbered `Blank N` sections with
A–D options and a correct answer. Optional target headings retain existing
fallbacks. This product does not treat a free-form essay prompt plus a marking
rubric as an Essay Builder sentence set; the preview explains the required
structure. No missing marking criteria or answers are invented.

Incomplete content is populated in the new **editable import review**, not saved
as an invalid Mission. Add missing sections in the original text and reparse;
the repair form edits extracted fields rather than providing a second question
or sentence-authoring system. Legacy file-import readiness and persistence rules
remain in force.

## Exact task files

Frontend (`focus_mission_app`):

- `lib/features/teacher/presentation/population_source_dialog.dart` — new shared chooser and editable preview.
- `lib/features/teacher/presentation/mission_builder_sheet.dart` — connect existing Objective/Theory/Essay imports and retain correct source-mode copy.
- `lib/features/teacher/presentation/assessment_mode_screen.dart` — connect dedicated assessment import, preserve ten-question guard and show detailed errors.
- `lib/core/utils/focus_mission_api.dart` — optional multipart `previewOnly` flag.
- `lib/shared/models/focus_mission_models.dart` — optional transient population fields in the existing response model.
- `test/population_source_dialog_test.dart` — new dialog regressions.
- `test/mission_builder_sheet_test.dart` — update API test double for optional preview parameter.
- `PASTE_TEXT_POPULATION_QA.md` — this report.

Backend (`focus_mission_backend`):

- `src/services/teacher.service.js` — shared parser review fields and read-only preview behavior.
- `src/routes/teacher.routes.js` — validate optional preview flag.
- `test/teacherPopulationPreview.test.js` — service, preservation and file regressions.

## Release status

Not deployed. Version remains 2.3.1. A release must isolate this explicit file list
from the pre-existing Pong/mentor work and use the existing paired Release Agent.
Deploy the backend preview support before the frontend: older backend versions
do not know that `previewOnly` must suppress draft creation. No new database
migration or third-party dependency is required.
