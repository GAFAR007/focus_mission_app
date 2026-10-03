/**
 * WHAT: A contained game theme for the three Pong routes.
 * WHY: The arena needs contrast and compact controls without changing lessons.
 * HOW: Scope a dark Material theme and background to the Pong route subtree.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'package:flutter/material.dart';

abstract final class PongColors {
  static const background = Color(0xFF080F1B);
  static const surface = Color(0xFF122237);
  static const cyan = Color(0xFF66E5DB);
  static const coral = Color(0xFFFF8994);
}

class PongScaffold extends StatelessWidget {
  const PongScaffold({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PongColors.cyan,
        brightness: Brightness.dark,
        surface: PongColors.surface,
      ),
      scaffoldBackgroundColor: PongColors.background,
      cardTheme: CardThemeData(
        color: PongColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF294159)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: PongColors.cyan,
          foregroundColor: PongColors.background,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: PongColors.cyan,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
    );
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.4,
                colors: [Color(0xFF192B42), PongColors.background],
              ),
            ),
            child: SafeArea(
              child: DefaultTextStyle(
                style: theme.textTheme.bodyMedium!,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
