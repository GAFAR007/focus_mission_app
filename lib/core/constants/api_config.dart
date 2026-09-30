/**
 * WHAT:
 * ApiConfig resolves the backend base URL used by the Flutter app.
 * WHY:
 * The same app runs on Flutter web and local device targets, so API routing
 * needs one shared place that adapts to the runtime host.
 * HOW:
 * Detect web vs non-web platforms and return the correct local API origin.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static String get baseUrl {
    // WHY: Explicit build configuration supports isolated local acceptance tests
    // without routing synthetic students through the production database.
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) {
      // WHY: Netlify-hosted web builds must use the deployed backend origin.
      return 'https://focus-mission-backend.onrender.com/api';
    }

    return 'http://127.0.0.1:4001/api';
  }
}
