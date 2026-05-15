import 'package:cortex/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TextStyles {
  // --- Header ---
  static TextStyle userNameStyle = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle userSubtitleStyle = GoogleFonts.roboto(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // --- Search ---
  static TextStyle searchHintStyle = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.iconLight,
  );

  // --- Quick Action Cards ---
  static TextStyle quickActionTitle = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle quickActionSubtitle = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle quickActionTitleWhite = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle quickActionSubtitleWhite = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Colors.white.withValues(alpha: 0.85),
  );

  // --- Section Headers ---
  static TextStyle sectionHeaderStyle = GoogleFonts.roboto(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // --- Note Card ---
  static TextStyle noteTitleStyle = GoogleFonts.roboto(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle noteContentStyle = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle todoItemStyle = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle tagStyle = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.tagText,
  );

  static TextStyle dateStyle = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // --- FAB ---
  static TextStyle fabTextStyle = GoogleFonts.roboto(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  // --- Edit Note Screen ---
  static TextStyle screenTitleStyle = GoogleFonts.roboto(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle inputTitleStyle = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle inputHintStyle = GoogleFonts.roboto(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.iconLight,
  );

  static TextStyle inputContentStyle = GoogleFonts.roboto(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.6,
  );

  static TextStyle actionChipStyle = GoogleFonts.roboto(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle aiCardTitle = GoogleFonts.roboto(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}
