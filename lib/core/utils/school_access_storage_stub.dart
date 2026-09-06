/**
 * WHAT:
 * school_access_storage_stub persists gate data outside Flutter Web.
 * WHY:
 * Mobile and widget-test builds cannot use browser sessionStorage but still
 * need predictable gate restoration behavior.
 * HOW:
 * Store one serialized, expiring grant through the existing preferences layer.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'focusMission.schoolAccessSession';

Future<String?> readSchoolAccessValue() async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getString(_storageKey);
}

Future<void> writeSchoolAccessValue(String value) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(_storageKey, value);
}

Future<void> clearSchoolAccessValue() async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.remove(_storageKey);
}
