/**
 * WHAT:
 * AppSpacing defines the shared spacing and radius tokens for the Flutter UI.
 * WHY:
 * Consistent spacing supports the ADHD-first design goal by keeping screens
 * predictable and visually calm.
 * HOW:
 * Expose static dimension tokens that widgets reuse for padding, gaps, and
 * rounded corners.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

abstract final class AppSpacing {
  static const screen = 24.0;
  static const section = 20.0;
  static const item = 16.0;
  static const compact = 12.0;
  static const chip = 10.0;
  static const radiusXl = 28.0;
  static const radiusLg = 24.0;
  static const radiusMd = 20.0;
}
