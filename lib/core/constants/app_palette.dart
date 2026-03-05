/**
 * WHAT:
 * AppPalette defines the shared colors and gradients for Focus Mission.
 * WHY:
 * The app needs one intentional visual system so ADHD-friendly screens stay
 * calm, consistent, and easy to recognize across roles.
 * HOW:
 * Expose reusable color constants and gradient presets for screens and widgets.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const backgroundTop = Color(0xFFF7FBFF);
  static const backgroundBottom = Color(0xFFE0EEFF);
  static const navy = Color(0xFF32456D);
  static const textMuted = Color(0xFF7A86A5);
  static const primaryBlue = Color(0xFF6B8CFF);
  static const aqua = Color(0xFF7FDDEB);
  static const mint = Color(0xFF93D88A);
  static const sun = Color(0xFFF6C764);
  static const orange = Color(0xFFF8AA5D);
  static const sky = Color(0xFFAEDBFF);
  static const surface = Color(0xFFFDFEFF);
  static const shadow = Color(0x224E6ED8);

  static const heroGradient = [Color(0xFFDDEEFF), Color(0xFFF8FCFF)];
  static const studentGradient = [Color(0xFF7FE3DA), Color(0xFFA2D86B)];
  static const teacherGradient = [Color(0xFF8BC4FF), Color(0xFFC4E2FF)];
  static const mentorGradient = [Color(0xFFFFD177), Color(0xFFFFEEA6)];
  static const progressGradient = [Color(0xFF88D77C), Color(0xFF5CCBC6)];
  static const backgroundGradient = [backgroundTop, backgroundBottom];
}
