/**
 * WHAT:
 * downloadTextFile exposes a small cross-platform wrapper for teacher export
 * downloads from the Flutter frontend.
 * WHY:
 * Teacher authoring flows need one safe way to export reviewed draft content
 * without adding backend endpoints or platform-specific logic inside screens.
 * HOW:
 * Delegate to a conditional implementation that uses browser downloads on web
 * and returns a safe fallback signal on unsupported platforms.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'download_text_file_stub.dart'
    if (dart.library.html) 'download_text_file_web.dart'
    as impl;

Future<bool> downloadTextFile({
  required String fileName,
  required String content,
  String mimeType = 'text/plain;charset=utf-8',
}) {
  return impl.downloadTextFile(
    fileName: fileName,
    content: content,
    mimeType: mimeType,
  );
}
