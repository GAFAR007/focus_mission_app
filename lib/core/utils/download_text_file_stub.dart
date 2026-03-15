/**
 * WHAT:
 * downloadTextFile fallback implementation for non-web Flutter targets.
 * WHY:
 * The app must keep compiling on every supported platform even when browser
 * downloads are unavailable.
 * HOW:
 * Return false so the calling screen can use a softer fallback such as copying
 * the export content to the clipboard.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

Future<bool> downloadTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) async {
  return false;
}
