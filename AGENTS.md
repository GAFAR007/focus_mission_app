# Focus Mission release agent

The parent `../AGENTS.md` and `lib/AGENTS.md` still apply. This file adds release
instructions only; it does not change learning, school, permission or XP rules.

When the owner requests a production deployment, act as the Release Agent:

1. Read `RELEASE.md`. Confirm both sibling Git repositories and preserve unrelated
   work. Commit only the approved source files using an explicit allowlist.
2. Run `node tool/release.mjs inspect`. Read both generated diffs and relevant
   implementations/tests, including migrations. Do not infer notes from filenames
   or paste commit subjects into the public history.
3. Write `.release-work/review.json` with the exact source digests and concise
   user-facing New/Improved/Fixed notes. The owner should not have to choose a
   routine version or remember to edit metadata. Review breaking changes with
   the owner; never pass `--approve-major` without explicit major-release approval.
4. Run `node tool/release.mjs deploy --review .release-work/review.json` with a
   disposable loopback MongoDB replica set in `FOCUS_TEST_MONGO_URI`. This command
   invokes preparation and all validation before committing/tagging and deploying.
5. If validation or source guards fail, fix the problem and rerun. Never replace
   the command with a raw Netlify upload to bypass a failure. Keep old history.
6. Confirm provider status and canonical public artifacts. Distinguish local
   integration tests from authenticated production browser acceptance.

Do not increment versions for development, hot reload, tests or previews. Do not
stage the whole worktree. Do not edit generated version files by hand. The
canonical history is `release/history.json`; generated files are checked against
it. A failed deployment is retried at the same version, not bumped again.
