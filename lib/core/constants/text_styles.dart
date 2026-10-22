import 'package:cortex/core/constants/colors.dart';
import 'package:flutter/material.dart';

/// iOS Dynamic Type scale (default size). Uses the platform font, which is
/// SF Pro on iOS.
class TextStyles {
  TextStyles._();

  /// Large title — 34 bold.
  static const TextStyle display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
    color: AppColors.textPrimary,
  );

  /// Note title inside the editor — Title 1, 28 bold.
  static const TextStyle headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.36,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// Section headers — Title 3, 20 semibold.
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.38,
    color: AppColors.textPrimary,
  );

  /// Card titles, row titles — Headline, 17 semibold.
  static const TextStyle cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    color: AppColors.textPrimary,
  );

  /// Reading / writing text — Body, 17.
  static const TextStyle body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  /// Previews and subtitles — Subheadline, 15.
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  /// Buttons, chips, field labels — 15 semibold.
  static const TextStyle label = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24,
    color: AppColors.textPrimary,
  );

  /// Dates, counts, section footers — Footnote, 13.
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    color: AppColors.textSecondary,
  );

  static const TextStyle hint = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    color: AppColors.textTertiary,
  );
}
