/**
 * WHAT:
 * standalone_paper_focus_monitor_stub provides a no-op focus monitor for
 * non-web standalone Test and Exam sessions.
 * WHY:
 * The student runner needs a single API for integrity hooks, but only web can
 * listen to browser tab and window focus events directly.
 * HOW:
 * Expose a monitor with the same lifecycle as the web implementation while
 * leaving all callbacks inactive on platforms that do not support them.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

typedef StandalonePaperFocusCallback = void Function();

abstract class StandalonePaperFocusMonitor {
  void start({
    required StandalonePaperFocusCallback onTabHidden,
    required StandalonePaperFocusCallback onWindowBlur,
    required StandalonePaperFocusCallback onFullscreenExit,
  });

  void dispose();
}

StandalonePaperFocusMonitor createStandalonePaperFocusMonitor() =>
    _StandalonePaperFocusMonitorStub();

class _StandalonePaperFocusMonitorStub implements StandalonePaperFocusMonitor {
  @override
  void start({
    required StandalonePaperFocusCallback onTabHidden,
    required StandalonePaperFocusCallback onWindowBlur,
    required StandalonePaperFocusCallback onFullscreenExit,
  }) {}

  @override
  void dispose() {}
}
