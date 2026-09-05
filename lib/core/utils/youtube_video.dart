/**
 * WHAT:
 * Parses optional teacher-supplied YouTube learning-video URLs and normalizes
 * their placement inside a mission question's learning sequence.
 * WHY:
 * Teacher preview and student playback must derive media only from recognized
 * YouTube video IDs instead of trusting arbitrary URLs or embed markup.
 * HOW:
 * Accept common YouTube share URL shapes, extract an eleven-character ID, and
 * expose canonical watch and thumbnail URLs with a safe placement default.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

abstract final class LearningVideoPlacements {
  static const beforeLearnFirst = 'beforeLearnFirst';
  static const afterLearnFirst = 'afterLearnFirst';
  static const afterExplanation = 'afterExplanation';

  static const values = <String>{
    beforeLearnFirst,
    afterLearnFirst,
    afterExplanation,
  };

  static String normalize(String? value) {
    final normalized = (value ?? '').trim();
    return values.contains(normalized) ? normalized : afterLearnFirst;
  }

  static String label(String value) {
    switch (normalize(value)) {
      case beforeLearnFirst:
        return 'Before Learn First';
      case afterExplanation:
        return 'After explanation';
      case afterLearnFirst:
        return 'After Learn First';
      default:
        // WHY: normalize currently guarantees one of the constants, while the
        // fallback keeps this String-based API total if that contract evolves.
        return 'After Learn First';
    }
  }
}

class YouTubeVideoReference {
  const YouTubeVideoReference({required this.videoId});

  final String videoId;

  String get canonicalUrl => 'https://www.youtube.com/watch?v=$videoId';
  String get thumbnailUrl => 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
}

YouTubeVideoReference? parseYouTubeVideoUrl(String? value) {
  final rawValue = (value ?? '').trim();
  if (rawValue.isEmpty || rawValue.contains(RegExp(r'[<>]'))) {
    return null;
  }

  final candidate =
      RegExp(r'^[a-z][a-z\d+.-]*://', caseSensitive: false).hasMatch(rawValue)
      ? rawValue
      : 'https://$rawValue';
  final uri = Uri.tryParse(candidate);
  if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) {
    return null;
  }

  final host = uri.host.toLowerCase();
  String videoId = '';
  if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
    videoId =
        uri.pathSegments.where((segment) => segment.isNotEmpty).firstOrNull ??
        '';
  } else if (host == 'youtube.com' || host.endsWith('.youtube.com')) {
    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    final firstSegment = segments.firstOrNull?.toLowerCase() ?? '';
    if (firstSegment == 'watch') {
      videoId = (uri.queryParameters['v'] ?? '').trim();
    } else if (const {'shorts', 'embed', 'live'}.contains(firstSegment) &&
        segments.length > 1) {
      videoId = segments[1].trim();
    }
  }

  if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) {
    return null;
  }

  return YouTubeVideoReference(videoId: videoId);
}

String? validateOptionalYouTubeVideoUrl(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized.length > 300 || parseYouTubeVideoUrl(normalized) == null) {
    return 'Paste a valid YouTube video link.';
  }
  return null;
}

bool supportsLearningVideosForMission({
  required String draftFormat,
  required int questionCount,
}) {
  final format = draftFormat.trim().toUpperCase();
  if (format == 'THEORY') {
    return true;
  }

  // WHY: Daily and Revision are learning modes. Assessment and longer
  // independent question sets must never expose teaching media.
  return format == 'QUESTIONS' && const {5, 8}.contains(questionCount);
}
