/**
 * WHAT:
 * auth_session_store persists the authenticated session token and cached user.
 * WHY:
 * Flutter web refreshes rebuild the whole app, so login continuity needs a
 * small local store instead of forcing the user back through sign-in each time.
 * HOW:
 * Save the token and user JSON in shared preferences, restore via `/auth/me`
 * when possible, and clear the store on sign-out or invalid auth.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/focus_mission_models.dart';
import 'focus_mission_api.dart';

class AuthSessionStore {
  static const String _tokenKey = 'focusMission.authToken';
  static const String _userKey = 'focusMission.authUser';

  Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(_userKey, jsonEncode(_userToJson(session.user)));
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<AuthSession?> restoreSession({required FocusMissionApi api}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString(_tokenKey) ?? '').trim();
    if (token.isEmpty) {
      return null;
    }

    final cachedUser = _cachedUserFromPrefs(prefs);

    try {
      final liveUser = await api.fetchCurrentUser(token: token);
      final restoredSession = AuthSession(token: token, user: liveUser);
      await saveSession(restoredSession);
      return restoredSession;
    } on FocusMissionApiException catch (error) {
      if (_isInvalidAuthMessage(error.message)) {
        // WHY: Expired or revoked tokens must be removed immediately so the
        // app does not keep retrying a session that the backend already denied.
        await clearSession();
        return null;
      }

      if (cachedUser != null) {
        // WHY: When the network is briefly unavailable, the cached identity
        // keeps the user inside the app instead of looking logged out again.
        return AuthSession(token: token, user: cachedUser);
      }

      return null;
    } catch (_) {
      if (cachedUser != null) {
        return AuthSession(token: token, user: cachedUser);
      }
      return null;
    }
  }

  AppUser? _cachedUserFromPrefs(SharedPreferences prefs) {
    final rawJson = (prefs.getString(_userKey) ?? '').trim();
    if (rawJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return AppUser.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  bool _isInvalidAuthMessage(String message) {
    final normalized = message.trim().toLowerCase();
    return normalized.contains('authentication required') ||
        normalized.contains('invalid token') ||
        normalized.contains('user not found for this token') ||
        normalized.contains('jwt expired') ||
        normalized.contains('this account has been archived');
  }

  Map<String, dynamic> _userToJson(AppUser user) {
    return {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role,
      'yearGroup': user.yearGroup,
      'subjectSpecialty': user.subjectSpecialty,
      'isPlaceholder': user.isPlaceholder,
      'avatar': user.avatar,
      'avatarSeed': user.avatarSeed,
      'xp': user.xp,
      'streak': user.streak,
      'streakBadgeUnlocked': user.streakBadgeUnlocked,
      'firstLoginAt': user.firstLoginAt,
      'lastLoginAt': user.lastLoginAt,
      'loginDayCount': user.loginDayCount,
      'daysSinceFirstLogin': user.daysSinceFirstLogin,
      'isArchived': user.isArchived,
      'archivedAt': user.archivedAt,
      'preferredDifficulty': user.preferredDifficulty,
      'assignedStudents': user.assignedStudents,
    };
  }
}
