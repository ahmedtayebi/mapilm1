import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2038F5);
  static const Color primaryLight = Color(0xFF5560F8);
  static const Color primaryLighter = Color(0xFFEEF0FE);
  static const Color primaryDark = Color(0xFF1229CC);
  static const Color primaryDarker = Color(0xFF0A1899);

  // ── Neutrals ───────────────────────────────────────────────────────────
  static const Color grey50 = Color(0xFFF8F9FC);
  static const Color grey100 = Color(0xFFF1F3F8);
  static const Color grey200 = Color(0xFFE2E6F0);
  static const Color grey300 = Color(0xFFC8CFDF);
  static const Color grey400 = Color(0xFF9BA5BB);
  static const Color grey500 = Color(0xFF6B7590);
  static const Color grey600 = Color(0xFF4C5468);
  static const Color grey700 = Color(0xFF333A4D);
  static const Color grey800 = Color(0xFF1E2333);
  static const Color grey900 = Color(0xFF0F1220);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color success = Color(0xFF00C853);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF8F00);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color info = Color(0xFF0288D1);
  static const Color infoLight = Color(0xFFE1F5FE);

  // ── Background / Surface ───────────────────────────────────────────────
  static const Color background = Color(0xFFF8F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F8);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // ── On Colors ──────────────────────────────────────────────────────────
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF0F1220);
  static const Color onSurface = Color(0xFF1E2333);
  static const Color onSurfaceVariant = Color(0xFF6B7590);

  // ── Chat specific ──────────────────────────────────────────────────────
  static const Color bubbleOutgoing = Color(0xFF2038F5);
  static const Color bubbleIncoming = Color(0xFFFFFFFF);
  static const Color onBubbleOutgoing = Color(0xFFFFFFFF);
  static const Color onBubbleIncoming = Color(0xFF1E2333);
  static const Color inputBackground = Color(0xFFF1F3F8);

  // ── Divider / Border ───────────────────────────────────────────────────
  static const Color divider = Color(0xFFE2E6F0);
  static const Color border = Color(0xFFE2E6F0);
  static const Color borderFocused = Color(0xFF2038F5);

  // ── Overlay ────────────────────────────────────────────────────────────
  static const Color scrim = Color(0x80000000);
  static const Color shimmerBase = Color(0xFFE8EBF5);
  static const Color shimmerHighlight = Color(0xFFF5F6FC);

  // ── Online status ──────────────────────────────────────────────────────
  static const Color online = Color(0xFF00C853);
  static const Color offline = Color(0xFF9BA5BB);
  static const Color away = Color(0xFFFF8F00);

  // ── Aurora redesign (v2) ───────────────────────────────────────────────
  // Warm pearl canvas, deep ink, multi-hue accent set used by the new
  // home / chat / dock surfaces. Heritage `primary` (#2038F5) stays the hero.
  static const Color pearl = Color(0xFFF6F4EE);
  static const Color pearlDeep = Color(0xFFEDEAE0);
  static const Color ink = Color(0xFF0A0F1F);
  static const Color inkSoft = Color(0xFF222740);
  static const Color inkMuted = Color(0xFF6E7392);

  static const Color violet = Color(0xFF7C5CFF);
  static const Color peach = Color(0xFFFF8A65);
  static const Color mint = Color(0xFF22D3B3);
  static const Color rose = Color(0xFFFF6B9B);
  static const Color amber = Color(0xFFFFB547);

  // Aurora gradient stops (electric blue → violet → rose) used for hero
  // accents (send button, active dock pill, presence rings).
  static const List<Color> auroraStops = [
    Color(0xFF2038F5),
    Color(0xFF6A4DFF),
    Color(0xFFC846E8),
    Color(0xFFFF6B9B),
  ];

  // Glass / edge tones for translucent cards.
  static const Color glassBorder = Color(0x1A0A0F1F);
  static const Color glassEdgeHi = Color(0x66FFFFFF);
  static const Color glassFill = Color(0xCCFFFFFF);
}
