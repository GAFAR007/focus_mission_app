/**
 * WHAT:
 * Tests the optional YouTube learning-video contract used by mission authoring
 * and student learning-mode rendering.
 * WHY:
 * Safe URL parsing, backward-compatible defaults, and assessment suppression
 * must remain deterministic without depending on YouTube network responses.
 * HOW:
 * Exercise common share URLs, invalid inputs, model decoding, placement
 * normalization, and mission-format display policy as pure unit tests.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:focus_mission_app/core/utils/focus_mission_api.dart';
import 'package:focus_mission_app/core/utils/youtube_video.dart';
import 'package:focus_mission_app/shared/models/focus_mission_models.dart';

void main() {
  group('YouTube URL parsing', () {
    const videoId = 'dQw4w9WgXcQ';
    final supportedUrls = <String>[
      'https://www.youtube.com/watch?v=$videoId',
      'https://youtu.be/$videoId?t=30',
      'youtube.com/shorts/$videoId',
      'https://www.youtube.com/embed/$videoId',
      'https://m.youtube.com/live/$videoId',
    ];

    for (final url in supportedUrls) {
      test('accepts $url', () {
        final parsed = parseYouTubeVideoUrl(url);
        expect(parsed?.videoId, videoId);
        expect(
          parsed?.canonicalUrl,
          'https://www.youtube.com/watch?v=$videoId',
        );
      });
    }

    test('rejects unsupported hosts, markup, and malformed ids', () {
      expect(
        parseYouTubeVideoUrl('https://example.com/watch?v=$videoId'),
        isNull,
      );
      expect(
        parseYouTubeVideoUrl('<iframe src="youtube.com"></iframe>'),
        isNull,
      );
      expect(parseYouTubeVideoUrl('https://youtu.be/too-short'), isNull);
      expect(validateOptionalYouTubeVideoUrl(''), isNull);
      expect(
        validateOptionalYouTubeVideoUrl('https://example.com/video'),
        'Paste a valid YouTube video link.',
      );
    });
  });

  test('old mission questions decode without video fields', () {
    final question = MissionQuestion.fromJson({
      'prompt': 'What is an online business?',
      'learningText': 'An online business trades using the internet.',
      'options': ['A', 'B', 'C', 'D'],
      'correctIndex': 0,
      'explanation': 'Option A is correct.',
    });

    expect(question.learningVideoUrl, isEmpty);
    expect(
      question.learningVideoPlacement,
      LearningVideoPlacements.afterLearnFirst,
    );
  });

  test('normalizes placement and independent-assessment policy', () {
    expect(
      LearningVideoPlacements.normalize(null),
      LearningVideoPlacements.afterLearnFirst,
    );
    expect(
      LearningVideoPlacements.normalize('unsupported'),
      LearningVideoPlacements.afterLearnFirst,
    );
    expect(
      supportsLearningVideosForMission(
        draftFormat: 'QUESTIONS',
        questionCount: 5,
      ),
      isTrue,
    );
    expect(
      supportsLearningVideosForMission(
        draftFormat: 'QUESTIONS',
        questionCount: 8,
      ),
      isTrue,
    );
    expect(
      supportsLearningVideosForMission(draftFormat: 'THEORY', questionCount: 3),
      isTrue,
    );
    for (final count in const [10, 15, 20]) {
      expect(
        supportsLearningVideosForMission(
          draftFormat: 'QUESTIONS',
          questionCount: count,
        ),
        isFalse,
      );
    }
    expect(
      supportsLearningVideosForMission(
        draftFormat: 'ESSAY_BUILDER',
        questionCount: 10,
      ),
      isFalse,
    );
  });

  test(
    'teacher mission updates send and decode learning-video fields',
    () async {
      late Map<String, dynamic> requestBody;
      final api = FocusMissionApi(
        client: MockClient((request) async {
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'mission': {
                'id': 'mission-1',
                'title': 'Business Online',
                'draftFormat': 'QUESTIONS',
                'questionCount': 1,
                'questions': requestBody['questions'],
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );

      final saved = await api.updateTeacherMission(
        token: 'teacher-token',
        missionId: 'mission-1',
        title: 'Business Online',
        teacherNote: '',
        sourceUnitText: 'Unit text',
        difficulty: 'medium',
        xpReward: 30,
        questions: const [
          MissionQuestion(
            id: 'question-1',
            answerMode: 'multiple_choice',
            learningText: 'Learn this first.',
            learningVideoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            learningVideoPlacement: LearningVideoPlacements.beforeLearnFirst,
            prompt: 'What is ecommerce?',
            options: ['Online trade', 'A building', 'A letter', 'A timetable'],
            correctIndex: 0,
            explanation: 'Ecommerce is online trade.',
            expectedAnswer: '',
            minWordCount: 0,
          ),
        ],
      );

      final questionJson =
          (requestBody['questions'] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(
        questionJson['learningVideoUrl'],
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(
        questionJson['learningVideoPlacement'],
        LearningVideoPlacements.beforeLearnFirst,
      );
      expect(
        saved.questions.single.learningVideoUrl,
        questionJson['learningVideoUrl'],
      );
      expect(
        saved.questions.single.learningVideoPlacement,
        LearningVideoPlacements.beforeLearnFirst,
      );
    },
  );
}
