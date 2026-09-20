/**
 * WHAT:
 * downloadBinaryFile exposes a small cross-platform wrapper for binary report
 * exports such as selectable PDFs.
 * WHY:
 * PDF bytes must be downloaded unchanged; routing them through a UTF-8 text
 * helper would corrupt the document.
 * HOW:
 * Delegate to a conditional web implementation and return false on platforms
 * where direct browser download is unavailable.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'download_binary_file_stub.dart'
    if (dart.library.html) 'download_binary_file_web.dart'
    as impl;

Future<bool> downloadBinaryFile({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) {
  return impl.downloadBinaryFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
}
