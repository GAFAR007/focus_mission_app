/**
 * WHAT:
 * Downloads unchanged binary report bytes in Flutter web.
 * WHY:
 * Selectable PDF evidence must stay a valid binary document rather than being
 * converted to text or a screenshot.
 * HOW:
 * Create a browser Blob, click a temporary download anchor, and revoke its URL.
 */
// ignore_for_file: avoid_web_libraries_in_flutter, dangling_library_doc_comments, deprecated_member_use, slash_for_doc_comments

import 'dart:html' as html;

Future<bool> downloadBinaryFile({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  final blob = html.Blob(<Object>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
