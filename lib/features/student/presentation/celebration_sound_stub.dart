/**
 * WHAT:
 * Stub celebration-sound helpers for non-web targets.
 * WHY:
 * MissionPlayScreen uses conditional imports, so non-web builds need a
 * compile-safe fallback with the same API.
 * HOW:
 * Expose no-op warmup/play functions that satisfy the shared interface.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

Future<void> warmupHurraySound() async {}

Future<void> playHurraySound() async {}
