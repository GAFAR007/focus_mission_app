/**
 * WHAT:
 * downloadTextFile web implementation for teacher draft exports.
 * WHY:
 * Browser-based teachers need one-click downloads of the reviewed draft text
 * they are preparing for students.
 * HOW:
 * Build a UTF-8 text blob, attach it to a temporary anchor element, and click
 * it programmatically so the browser saves the file locally.
 */
// ignore_for_file: avoid_web_libraries_in_flutter, dangling_library_doc_comments, deprecated_member_use, slash_for_doc_comments

import 'dart:convert';
import 'dart:html' as html;

Future<bool> downloadTextFile({
  required String fileName,
  required String content,
}) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob(<Object>[bytes], 'text/plain;charset=utf-8');
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
