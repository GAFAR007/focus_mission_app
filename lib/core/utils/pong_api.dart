/**
 * WHAT: Authenticated HTTP commands and streaming snapshots for Pong.
 * WHY: UI sends controls only; the backend owns permissions and results.
 * HOW: Reuse the installed HTTP client, bearer auth and configured API origin.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import '../../shared/models/pong_models.dart';

class PongApiException implements Exception {
  PongApiException(this.message, this.code);
  final String message, code;
  @override
  String toString() => message;
}

class PongApi {
  PongApi(this.token, {http.Client? client})
    : _client = client ?? http.Client();
  final String token;
  final http.Client _client;
  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
  Future<PongJson> request(String method, String path, [PongJson? body]) async {
    final req = http.Request(
      method,
      Uri.parse('${ApiConfig.baseUrl}/pong$path'),
    )..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(req),
    ).timeout(const Duration(seconds: 20));
    final data = pongMap(jsonDecode(response.body));
    if (response.statusCode >= 400) {
      throw PongApiException(
        data['message'] as String? ?? 'Please try again.',
        data['code'] as String? ?? 'PONG_ERROR',
      );
    }
    return data;
  }

  Future<PongProfile> me() async =>
      PongProfile.fromJson(await request('GET', '/me'));
  Future<PongFrame> match(String handle) async =>
      PongFrame.fromJson(await request('GET', '/matches/$handle'));
  Future<PongLobby> lobby(String search) async => PongLobby.fromJson(
    await request('GET', '/lobby?search=${Uri.encodeQueryComponent(search)}'),
  );
  Future<String> computer(int level) async =>
      (await request('POST', '/computer', {'level': level}))['match'] as String;
  Future<void> challenge(
    String opponent, {
    String? rematchOf,
    String ruleset = 'classic',
  }) async {
    await request('POST', '/challenges', {
      'opponent': opponent,
      'ruleset': ruleset,
      'rematchOf': ?rematchOf,
    });
  }

  Future<String?> respond(
    String handle,
    String action, {
    String? ruleset,
  }) async =>
      (await request('POST', '/challenges/$handle', {
            'action': action,
            'ruleset': ?ruleset,
          }))['match']
          as String?;
  Future<void> control(String handle, String action) async {
    await request('POST', '/matches/$handle/control', {'action': action});
  }

  Future<void> input(
    String handle,
    String controlToken,
    int seq,
    int direction,
    double? targetY, {
    int forward = 0,
  }) async {
    await request('POST', '/matches/$handle/input', {
      'controlToken': controlToken,
      'seq': seq,
      'direction': direction,
      'targetY': ?targetY,
      'forward': forward,
    });
  }

  Stream<PongFrame> frames(String handle) async* {
    // WHY: A separate client makes cancelling the arena stream independent of
    // the final leave/restart command. Tokens never appear in URLs or logs.
    final streamClient = http.Client();
    try {
      final request = http.Request(
        'GET',
        Uri.parse('${ApiConfig.baseUrl}/pong/matches/$handle/stream'),
      )..headers.addAll(_headers);
      final response = await streamClient.send(request);
      if (response.statusCode != 200) {
        final data = pongMap(jsonDecode(await response.stream.bytesToString()));
        throw PongApiException(
          data['message'] as String,
          data['code'] as String,
        );
      }
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          yield PongFrame.fromJson(pongMap(jsonDecode(line.substring(6))));
        }
      }
    } finally {
      streamClient.close();
    }
  }

  void close() => _client.close();
}
