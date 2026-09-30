# Production releases

The owner-confirmed previous public version is **2.0.0**. Older pubspec/package
values were stale. The imported 2.0.0 entry records the verified prior production
revisions; its original publication date is unknown and is not invented.

## One version source

`release/history.json` is canonical and append-only, newest first. The command
generates the Dart history, public `web/release.json`, Flutter pubspec version,
and the backend package/lockfile version and `release.json`. Never edit those
copies independently. API protocol `v1` and third-party dependency versions are
separate contracts and are not application versions.

The public manifest contains release notes and the reviewed source commits.
Those commits precede the metadata-only `release: vX.Y.Z` commit: a file cannot
contain its own Git commit hash. The `vX.Y.Z` tag points to the final release
commit. `deployed/vX.Y.Z` is created only after both providers and public artifact
hashes are verified; only that production marker is used as the next baseline.

## Tell the agent to deploy

The repository agent instructions make release review part of every deployment.
The agent commits the scoped implementation, runs:

```sh
node tool/release.mjs inspect
```

It reads `.release-work/inspection.json`, both actual diffs and relevant tests,
then writes `.release-work/review.json`:

```json
{
  "previousVersion": "2.0.0",
  "frontendDigest": "exact digest from inspection",
  "backendDigest": "exact digest from inspection",
  "title": "Mission creation and release history",
  "breaking": false,
  "changes": {
    "new": ["See what changed in each release from the version button."],
    "improved": [],
    "fixed": ["Fixed an issue that could prevent teachers from creating missions."]
  },
  "evidence": ["Reviewed the upload callback and school isolation tests."]
}
```

The coding agent performs the semantic review; a deterministic script cannot
reliably infer user impact from arbitrary code. Missing/stale reviews stop the
release rather than inventing notes. No new AI API, credential or dependency is
required, and the owner does not manually bump a version.

```sh
# FOCUS_TEST_MONGO_URI must already name a disposable local replica set.
node tool/release.mjs deploy --review .release-work/review.json
```

The deployment command itself invokes `prepare-release`. New features imply
MINOR; fixes/improvements imply PATCH; mixed changes use the larger bump.
Breaking changes stop unless the owner deliberately approves MAJOR. Repeated
preparation of identical source is a no-op, including retries after provider
failure. New changes while a prepared release is pending stop for review.

## Required validation and deployment

The command archives committed source from both repositories, overlays only
generated release metadata and runs these existing checks in the clean copies:

- Node release-command regression tests and backend JavaScript syntax checks.
- `npm ci` and `node --test --test-reporter=tap test/*.test.js` with a loopback
  replica set. Database suites must run; any skipped backend test blocks release.
- `flutter pub get`, `flutter analyze`, the full `flutter test` suite and
  `flutter build web --release`.

The existing suites cover login/session restoration, management, mission
creation/assignment, Objective/Theory/Essay, Test/Exam, result reports/evidence,
reuse/redo, archive, XP/leaderboard, certification and school boundaries. The
database suites use synthetic accounts; they do not modify production learners.
External AI generation is deterministic in the school workflow regression test.
Passing these checks is not a claim of real production AI/manual UI acceptance.

Validation receipts and build logs stay in `.release-work`/a temporary archive.
Only generated metadata is staged for `release: vX.Y.Z`; unrelated working edits
are excluded. The command pushes the backend and waits for its health endpoint
to identify the exact Render commit, version and source digest. Then it publishes
the validated archive to the existing Netlify site and checks canonical and
unique deploy URL bytes for index, JavaScript, bootstrap and both version files.

Render still auto-deploys from main. Its production startup now rejects missing,
pending or stale release evidence before connecting to the database. The health
commit uses Render's documented `RENDER_GIT_COMMIT` environment variable:
https://render.com/docs/environment-variables

The existing GitHub workflow checks release metadata on pushes. Publishing is
manual through the guarded release command; workflow dispatch remains available
for republishing an already validated version. Provider administrator access can
still upload arbitrary files directly: repository guards cannot revoke that
access. Agents must use the supported command and must not bypass its checks.

## Local development and recovery

Normal Flutter builds/hot reload and `npm run dev` do not change versions.
No release tools run during tests or previews unless explicitly invoked.

If validation fails, the release stays pending and nothing is published. Fix
the source, then discard only the uncommitted generated pending entry/copies and
rerun inspection/preparation; never delete a tagged or deployed history entry.
If deployment fails after validation/tagging, rerun `deploy` unchanged; it reuses
the same version and validated artifacts. If temporary artifacts were removed,
the command runs validation again.

Last-viewed release is stored separately for each account on each browser/device
using existing local preferences. It is informational only, has no effect on
missions, and is not a cross-device server preference.
