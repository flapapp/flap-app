import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_theme.dart';

/// Semantic design tokens and [ThemeData] for FLAP — dark-first, pitch + accent.
abstract final class FlapTheme {
  static const Color pitch = AppColors.bgBase;
  static const Color surface = AppColors.bgElevated;
  static const Color surfaceElevated = AppColors.bgElevated;
  static const Color outlineMuted = AppColors.borderSubtle;
  static const Color accent = AppColors.accentPrimary;
  static const Color accentDim = AppColors.accentPressed;
  static const Color accentSecondary = AppColors.accentSoft;
  static const Color danger = AppColors.error;
  static const Color onDark = AppColors.textPrimary;
  static const Color onDarkMuted = AppColors.textSecondary;

  static const double radiusSm = AppRadius.sm;
  static const double radiusMd = AppRadius.lg;
  static const double radiusLg = AppRadius.xl;
  static const double spaceXs = AppSpacing.xxs;
  static const double spaceSm = AppSpacing.xs;
  static const double spaceMd = AppSpacing.md;
  static const double spaceLg = AppSpacing.xl;
  static const double spaceXl = AppSpacing.xxl;

  static ThemeData theme() => AppTheme.dark2025();
}
