/**
 * WHAT: Maps canonical server coordinates into each player's vertical court.
 * WHY: Both students defend the bottom with natural left/right controls.
 * HOW: Inverse quarter-turn mappings preserve one authoritative game state.
 * WHO: Student Pong presentation owns client-side court projection.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'dart:ui';

abstract final class PongCourt {
  static const width = 560.0, height = 1000.0;
  static Offset project(Offset point, int side) => side == 0
      ? Offset(point.dy, height - point.dx)
      : Offset(width - point.dy, point.dx);
  static double target(double screenFraction, int side) =>
      (side == 0 ? screenFraction : 1 - screenFraction).clamp(0, 1) * width;
  static int direction(int localDirection, int side) =>
      side == 0 ? localDirection : -localDirection;
  static double intensity(double speed, double cap) =>
      cap <= 0 ? 0 : (speed / cap).clamp(0, 1);
}
