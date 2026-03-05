/**
 * WHAT:
 * main.dart boots the Flutter application and mounts the first auth screen.
 * WHY:
 * The app needs one entrypoint that always applies the shared theme before any
 * role-specific workflow begins.
 * HOW:
 * Start Flutter, create the FocusMissionApp widget, and point MaterialApp at
 * the role selection screen.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/role_selection_screen.dart';

void main() {
  runApp(const FocusMissionApp());
}

class FocusMissionApp extends StatelessWidget {
  const FocusMissionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Mission',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const RoleSelectionScreen(),
    );
  }
}
