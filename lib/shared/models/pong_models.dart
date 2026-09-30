/**
 * WHAT: Typed game-only profiles, invitations and authoritative arena frames.
 * WHY: UI rendering must not infer permission, score or level unlocks.
 * HOW: Decode the Pong API's privacy-safe response contracts.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

typedef PongJson = Map<String, dynamic>;
PongJson pongMap(dynamic value) => (value as Map).cast<String, dynamic>();
List<PongJson> pongRows(dynamic value) =>
    (value as List? ?? []).map(pongMap).toList();

class PongAccess {
  PongAccess.fromJson(PongJson json)
    : enabled = json['enabled'] == true,
      computer = json['computer'] == true,
      battles = json['battles'] == true,
      lobbyVisible = json['lobbyVisible'] == true;
  final bool enabled, computer, battles, lobbyVisible;
  PongJson toJson() => {
    'enabled': enabled,
    'computer': computer,
    'battles': battles,
    'lobbyVisible': lobbyVisible,
  };
}

class PongProgress {
  PongProgress.fromJson(PongJson json)
    : highestUnlocked = json['highestUnlocked'] as int? ?? 1,
      completedLevels = List<int>.from(json['completedLevels'] ?? []),
      bestRally = json['bestRally'] as int? ?? 0,
      computerWins = json['computerWins'] as int? ?? 0,
      multiplayerWins = json['multiplayerWins'] as int? ?? 0,
      multiplayerLosses = json['multiplayerLosses'] as int? ?? 0,
      matchesPlayed = json['matchesPlayed'] as int? ?? 0;
  final int highestUnlocked,
      bestRally,
      computerWins,
      multiplayerWins,
      multiplayerLosses,
      matchesPlayed;
  final List<int> completedLevels;
}

class PongLevel {
  PongLevel.fromJson(PongJson json)
    : level = json['level'] as int,
      name = json['name'] as String,
      goal = json['goal'] as int,
      arena = json['arena'] as String;
  final int level, goal;
  final String name, arena;
}

class PongProfile {
  PongProfile.fromJson(PongJson json)
    : access = PongAccess.fromJson(pongMap(json['access'])),
      progress = PongProgress.fromJson(pongMap(json['progress'])),
      activeMatch = json['activeMatch'] as String?,
      levels = pongRows(json['levels']).map(PongLevel.fromJson).toList();
  final PongAccess access;
  final PongProgress progress;
  final String? activeMatch;
  final List<PongLevel> levels;
}

class PongOpponent {
  PongOpponent.fromJson(PongJson json)
    : handle = json['handle'] as String,
      name = json['name'] as String,
      level = json['level'] as int,
      wins = json['wins'] as int,
      availability = json['availability'] as String;
  final String handle, name, availability;
  final int level, wins;
}

class PongInvitation {
  PongInvitation.fromJson(PongJson json)
    : handle = json['handle'] as String,
      name = json['name'] as String,
      incoming = json['incoming'] == true,
      status = json['status'] as String,
      expiresIn = json['expiresIn'] as int,
      match = json['match'] as String?;
  final String handle, name, status;
  final bool incoming;
  final int expiresIn;
  final String? match;
}

class PongLobby {
  PongLobby.fromJson(PongJson json)
    : students = pongRows(json['students']).map(PongOpponent.fromJson).toList(),
      challenges = pongRows(
        json['challenges'],
      ).map(PongInvitation.fromJson).toList();
  final List<PongOpponent> students;
  final List<PongInvitation> challenges;
}

class PongFrame {
  PongFrame.fromJson(PongJson json)
    : handle = json['handle'] as String,
      status = json['status'] as String,
      reason = json['reason'] as String? ?? '',
      side = json['side'] as int,
      players = pongRows(json['players']),
      state = pongMap(json['state']),
      controlToken = json['controlToken'] as String?,
      paused = json['paused'] == true,
      waiting = json['waiting'] == true,
      reconnectSeconds = json['reconnectSeconds'] as int? ?? 0,
      connectionError = json['connectionError'] as String?;
  final String handle, status, reason;
  final int side, reconnectSeconds;
  final String? controlToken, connectionError;
  final bool paused, waiting;
  final List<PongJson> players;
  final PongJson state;
  bool get computer => state['mode'] == 'computer';
  bool get ended => status != 'active';
  int get level => state['level'] as int;
  int get returns => state['returns'] as int;
  int get goal => state['goal'] as int;
  List<int> get score => List<int>.from(state['score']);
  int get longestRally => state['longestRally'] as int;
}
