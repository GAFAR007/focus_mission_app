/**
 * WHAT:
 * school_access_storage_web persists a gate grant in browser sessionStorage.
 * WHY:
 * School access should survive refresh and role navigation without becoming an
 * indefinite unlock after the browser session closes.
 * HOW:
 * Read, write, and clear one serialized grant using the current tab session.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:web/web.dart' as web;

const _storageKey = 'focusMission.schoolAccessSession';

Future<String?> readSchoolAccessValue() async {
  return web.window.sessionStorage.getItem(_storageKey);
}

Future<void> writeSchoolAccessValue(String value) async {
  web.window.sessionStorage.setItem(_storageKey, value);
}

Future<void> clearSchoolAccessValue() async {
  web.window.sessionStorage.removeItem(_storageKey);
}
