import 'package:flutter/material.dart';

/// Renders a badge's stored emoji glyph (from the DB) directly, restoring the
/// app's original emoji-based badge/skill visuals. Falls back to a medal glyph
/// for badges with no emoji set.
///
/// [size] is the desired glyph height in logical pixels (matches the font size
/// the old [Icon] used).
Widget flapBadgeGlyph(String? emoji, {double size = 22}) {
  final glyph = (emoji ?? '').trim();
  return Text(
    glyph.isEmpty ? '🏅' : glyph,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: size, height: 1.0),
  );
}
