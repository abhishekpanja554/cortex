import 'package:flutter/painting.dart';

/// Shapes for Cortex's iOS-style UI.
///
/// iOS draws rounded corners as "continuous" curves (a superellipse) rather
/// than circular arcs, which is a big part of why native UI looks softer.
/// Flutter ships the same curve as [RoundedSuperellipseBorder].
class AppShapes {
  AppShapes._();

  /// A rectangle with iOS continuous corners.
  static ShapeBorder continuous(double radius, {BorderSide side = BorderSide.none}) {
    return RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: side,
    );
  }

  /// A capsule (fully rounded ends), as used by iOS buttons and tab bars.
  static const ShapeBorder capsule = StadiumBorder();

  static const ShapeBorder circle = CircleBorder();
}
