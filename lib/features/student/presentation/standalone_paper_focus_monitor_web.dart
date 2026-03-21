/**
 * WHAT:
 * standalone_paper_focus_monitor_web listens for browser focus changes during
 * standalone Test and Exam sessions.
 * WHY:
 * Web delivery must report tab hides, window blur, and fullscreen exits so the
 * standalone anti-cheat policy applies only inside test and exam runners.
 * HOW:
 * Attach lightweight DOM listeners through dart:html and call back into the
 * runner whenever the browser leaves the active exam context.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments, avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'standalone_paper_focus_monitor_stub.dart';

StandalonePaperFocusMonitor createStandalonePaperFocusMonitor() =>
    _StandalonePaperFocusMonitorWeb();

class _StandalonePaperFocusMonitorWeb implements StandalonePaperFocusMonitor {
  StreamSubscription<html.Event>? _visibilitySubscription;
  StreamSubscription<html.Event>? _blurSubscription;
  StreamSubscription<html.Event>? _fullscreenSubscription;

  @override
  void start({
    required StandalonePaperFocusCallback onTabHidden,
    required StandalonePaperFocusCallback onWindowBlur,
    required StandalonePaperFocusCallback onFullscreenExit,
  }) {
    dispose();
    _visibilitySubscription = html.document.onVisibilityChange.listen((_) {
      if (html.document.hidden == true) {
        onTabHidden();
      }
    });
    _blurSubscription = html.window.onBlur.listen((_) => onWindowBlur());
    _fullscreenSubscription = html.document.onFullscreenChange.listen((_) {
      if (html.document.fullscreenElement == null) {
        onFullscreenExit();
      }
    });
  }

  @override
  void dispose() {
    _visibilitySubscription?.cancel();
    _blurSubscription?.cancel();
    _fullscreenSubscription?.cancel();
    _visibilitySubscription = null;
    _blurSubscription = null;
    _fullscreenSubscription = null;
  }
}
