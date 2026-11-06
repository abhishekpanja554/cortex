import 'dart:ui';

/// Cortex colour tokens, modelled on the iOS system palette so the app sits
/// naturally next to native iOS apps.
class AppColors {
  AppColors._();

  // Brand / tint (iOS systemBlue)
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryDark = Color(0xFF0062CC);
  static const Color primarySoft = Color(0xFFE5F0FF);

  // iOS system colours used for icon tiles and status
  static const Color indigo = Color(0xFF5856D6);
  static const Color green = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color red = Color(0xFFFF3B30);
  static const Color teal = Color(0xFF30B0C7);
  static const Color gray = Color(0xFF8E8E93);

  // Surfaces (systemGroupedBackground & friends)
  static const Color background = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFE9E9EF); // tertiarySystemFill-ish
  static const Color border = Color(0x2E3C3C43); // separator (#3C3C43 @ 18%)

  // Labels
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0x993C3C43); // secondaryLabel
  static const Color textTertiary = Color(0x4D3C3C43); // tertiaryLabel
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Status
  static const Color danger = red;
  static const Color dangerSoft = Color(0xFFFFE9E7);
  static const Color warning = Color(0xFFE65100);
  static const Color warningSoft = Color(0xFFFFF3E0);
  static const Color success = Color(0xFF248A3D);
  static const Color successSoft = Color(0xFFE3F6E8);

  // Liquid glass
  static const Color glassFill = Color(0xB8FFFFFF); // white @ 72%
  static const Color glassFillStrong = Color(0xE0FFFFFF); // white @ 88%
  static const Color glassRim = Color(0xFFFFFFFF);
  static const Color glassShadow = Color(0x1F000000);

  // Ambient background blobs (very light, sit behind glass)
  static const Color ambientBlue = Color(0xFFD6E6FF);
  static const Color ambientPurple = Color(0xFFEADFFF);
  static const Color ambientTeal = Color(0xFFD5F3F0);

  // Lock / PIN screens
  static const Color lockBackground = Color(0xFF0B0D12);

  // Legacy names kept so older code (splash, conflict UI) keeps compiling.
  static const Color secondary = Color(0xFF9F4CD7);
  static const Color searchBarBackground = background;
  static const Color borderColor = border;
  static const Color iconDefault = textSecondary;
  static const Color iconLight = textTertiary;
  static const Color todoCheckbox = primary;
}
