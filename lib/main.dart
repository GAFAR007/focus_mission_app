/**
 * WHAT:
 * main.dart boots the Flutter application and restores any saved auth session.
 * WHY:
 * Web refresh rebuilds the app from scratch, so the user should return to
 * their workspace when a valid session token is already stored locally.
 * HOW:
 * Start Flutter, restore the saved token through the auth API, and route to
 * either the restored workspace or the role selection screen.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import 'core/constants/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/auth_session_store.dart';
import 'core/utils/focus_mission_api.dart';
import 'features/auth/presentation/role_selection_screen.dart';
import 'features/management/presentation/management_overview_screen.dart';
import 'features/mentor/presentation/mentor_overview_screen.dart';
import 'features/student/presentation/student_dashboard_screen.dart';
import 'features/teacher/presentation/teacher_session_screen.dart';
import 'shared/models/focus_mission_models.dart';
import 'shared/widgets/avatar_badge.dart';
import 'shared/widgets/focus_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FocusMissionApp());
}

class FocusMissionApp extends StatefulWidget {
  const FocusMissionApp({super.key});

  @override
  State<FocusMissionApp> createState() => _FocusMissionAppState();
}

class _FocusMissionAppState extends State<FocusMissionApp> {
  late final Future<AuthSession?> _restoredSessionFuture;

  @override
  void initState() {
    super.initState();
    _restoredSessionFuture = AuthSessionStore().restoreSession(
      api: FocusMissionApi(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Mission',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FutureBuilder<AuthSession?>(
        future: _restoredSessionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _BootLoadingScreen();
          }

          final session = snapshot.data;
          if (session == null) {
            return const RoleSelectionScreen();
          }

          return _destinationForSession(session);
        },
      ),
    );
  }

  Widget _destinationForSession(AuthSession session) {
    switch (session.user.role) {
      case 'student':
        return StudentDashboardScreen(session: session);
      case 'teacher':
        return TeacherSessionScreen(session: session);
      case 'mentor':
        return MentorOverviewScreen(session: session);
      case 'management':
        return ManagementOverviewScreen(session: session);
      default:
        return const RoleSelectionScreen();
    }
  }
}

class _BootLoadingScreen extends StatelessWidget {
  const _BootLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AvatarBadge(
                icon: Icons.track_changes_rounded,
                colors: AppPalette.studentGradient,
                size: 68,
              ),
              const SizedBox(height: 18),
              Text(
                'Restoring your session...',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Getting your workspace ready.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
