/**
 * WHAT: Exercises semantic versioning and real Git release preparation.
 * WHY: Repeated commands, stale reviews and unversioned changes must not publish.
 * HOW: Use disposable local repositories and the actual command, never providers.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { nextVersion, snapshot, git, verifyReview, dartHistory } from './release.mjs';

test('semantic bumps combine features and fixes and require explicit major review', () => {
  assert.equal(nextVersion('2.0.0', { fixed: ['Mission fix'] }), '2.0.1');
  assert.equal(nextVersion('2.0.0', { new: ['History'], fixed: ['Mission fix'] }), '2.1.0');
  assert.throws(() => nextVersion('2.0.0', {}, true), /explicit major/);
  assert.equal(nextVersion('2.0.0', {}, true, true), '3.0.0');
  assert.throws(() => nextVersion('2.0.0', {}), /No user-facing/);
});

test('review is bound to both repositories and cannot silently accept changed source', () => {
  const review = { previousVersion: '2.0.0', frontendDigest: 'f', backendDigest: 'b', title: 'Updates', breaking: false, changes: { new: [], improved: [], fixed: ['Mission creation'] }, evidence: ['Reviewed the source extraction request callback.'] };
  verifyReview(review, { frontend: { digest: 'f' }, backend: { digest: 'b' } }, '2.0.0');
  assert.throws(() => verifyReview(review, { frontend: { digest: 'new' }, backend: { digest: 'b' } }, '2.0.0'), /stale/);
  assert.throws(() => verifyReview({ ...review, evidence: [] }, { frontend: { digest: 'f' }, backend: { digest: 'b' } }, '2.0.0'), /code evidence/);
});

test('real preparation is idempotent, preserves history and blocks unvalidated publication', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'release-command-test-'));
  const frontend = path.join(directory, 'frontend'); const backend = path.join(directory, 'backend');
  function put(root, file, text) { fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true }); fs.writeFileSync(path.join(root, file), text); }
  function commit(root, title) { git(root, 'add', '.'); git(root, 'commit', '-m', title); return git(root, 'rev-parse', 'HEAD'); }
  try {
    for (const root of [frontend, backend]) {
      fs.mkdirSync(root); git(root, 'init', '-b', 'main'); git(root, 'config', 'user.email', 'fixture@invalid'); git(root, 'config', 'user.name', 'Release fixture');
    }
    put(frontend, 'pubspec.yaml', 'name: fixture\nversion: 1.0.0+1\n');
    put(frontend, 'lib/main.dart', 'void main() {}\n');
    put(frontend, 'lib/core/constants/.keep', '');
    put(frontend, 'web/.keep', '');
    put(frontend, 'tool/release.mjs', fs.readFileSync(new URL('./release.mjs', import.meta.url)));
    put(backend, 'package.json', '{"name":"fixture","version":"1.0.0"}');
    put(backend, 'package-lock.json', '{"version":"1.0.0","packages":{"":{"version":"1.0.0"}}}');
    put(backend, 'server.js', '// fixture\n');
    const f = commit(frontend, 'Existing frontend'); const b = commit(backend, 'Existing backend');
    const previous = { version: '2.0.0', previousVersion: null, releasedAt: null, title: 'Previous release', changes: { new: [], improved: ['Existing learning tools'], fixed: [] }, source: { frontend: { commit: f }, backend: { commit: b } }, provenance: 'Synthetic production baseline' };
    put(frontend, 'release/history.json', JSON.stringify({ schemaVersion: 1, releases: [previous] }));
    put(frontend, 'lib/main.dart', 'void main() { /* New history UI */ }\n');
    commit(frontend, 'Add history');
    const frontSource = snapshot(frontend); const backSource = snapshot(backend, 'HEAD', true);
    const review = path.join(directory, 'review.json');
    fs.writeFileSync(review, JSON.stringify({ previousVersion: '2.0.0', frontendDigest: frontSource.digest, backendDigest: backSource.digest, title: 'Version history', breaking: false, changes: { new: ['See previous releases.'], improved: [], fixed: [] }, evidence: ['Reviewed the new history UI and persistence.'] }));
    const invoke = command => execFileSync(process.execPath, ['tool/release.mjs', command, '--backend', backend, '--review', review], { cwd: frontend, encoding: 'utf8', env: { ...process.env, FOCUS_TEST_MONGO_URI: '' }, stdio: ['ignore', 'pipe', 'pipe'] });
    invoke('prepare-release');
    const first = fs.readFileSync(path.join(frontend, 'release/history.json'), 'utf8');
    invoke('prepare-release');
    assert.equal(fs.readFileSync(path.join(frontend, 'release/history.json'), 'utf8'), first);
    const history = JSON.parse(first);
    assert.equal(history.releases[0].version, '2.1.0');
    assert.deepEqual(history.releases[1], previous);
    assert.equal(history.releases.length, 2);
    assert.match(fs.readFileSync(path.join(frontend, 'pubspec.yaml'), 'utf8'), /version: 2.1.0\+2/);
    assert.equal(snapshot(frontend).digest, frontSource.digest);
    assert.equal(snapshot(backend, 'HEAD', true).digest, backSource.digest);
    assert.equal(fs.readFileSync(path.join(frontend, 'lib/core/constants/release_history.g.dart'), 'utf8'), dartHistory(history));
    assert.throws(() => invoke('check'), /validation has not passed/);
    assert.throws(() => invoke('validate'), /replica set/);
    put(frontend, 'lib/main.dart', 'void main() { /* Another change */ }\n');
    commit(frontend, 'Another feature');
    assert.throws(() => invoke('prepare-release'), /Finish deploying prepared/);
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
