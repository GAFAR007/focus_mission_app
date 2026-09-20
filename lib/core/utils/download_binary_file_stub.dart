/**
 * WHAT:
 * Provides the non-web fallback for binary report downloads.
 * WHY:
 * The shared Draft Report screen must compile on every Flutter target even
 * when a browser download API is unavailable.
 * HOW:
 * Return false so the caller can show a clear unsupported-platform message.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

Future<bool> downloadBinaryFile({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  return false;
}
