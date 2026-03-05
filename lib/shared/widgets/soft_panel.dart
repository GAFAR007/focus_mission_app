/**
 * WHAT:
 * SoftPanel is the shared rounded glass-like surface wrapper used across the
 * app.
 * WHY:
 * A reusable surface component keeps the UI consistent and prevents each
 * screen from reimplementing premium card styling.
 * HOW:
 * Render a decorated container with gradient fill, rounded corners, and soft
 * shadow around the child widget.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';
import '../../core/constants/app_spacing.dart';

class SoftPanel extends StatelessWidget {
  const SoftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.section),
    this.colors,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<Color>? colors;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              colors ??
              [
                Colors.white.withValues(alpha: 0.90),
                Colors.white.withValues(alpha: 0.74),
              ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        boxShadow: const [
          BoxShadow(
            color: AppPalette.shadow,
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}
