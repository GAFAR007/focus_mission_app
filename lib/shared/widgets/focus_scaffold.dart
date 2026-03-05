/**
 * WHAT:
 * FocusScaffold provides the shared gradient background and decorative layer
 * for the app.
 * WHY:
 * Student-facing screens should feel consistent and calm without each page
 * reimplementing the background treatment.
 * HOW:
 * Wrap the child in a scaffold, paint the shared background gradient, and add
 * soft bubble accents behind the content.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';

class FocusScaffold extends StatelessWidget {
  const FocusScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppPalette.backgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              left: -40,
              child: _GlowBubble(
                size: 220,
                color: AppPalette.sky.withValues(alpha: 0.32),
              ),
            ),
            Positioned(
              top: 140,
              right: -24,
              child: _GlowBubble(
                size: 180,
                color: AppPalette.aqua.withValues(alpha: 0.20),
              ),
            ),
            Positioned(
              bottom: -80,
              left: 32,
              child: _GlowBubble(
                size: 200,
                color: AppPalette.sun.withValues(alpha: 0.12),
              ),
            ),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  const _GlowBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
