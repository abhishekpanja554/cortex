import 'dart:ui' as ui;

import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/theme/app_shapes.dart';
import 'package:flutter/material.dart';

/// An approximation of iOS 26 "Liquid Glass" in Flutter.
///
/// Real Liquid Glass refracts and lenses the content beneath it, which
/// Flutter can't do. This gets close with the parts we *can* render:
///   1. a backdrop blur with boosted saturation (colours stay vivid through
///      the glass instead of washing out),
///   2. a translucent tint with a soft top-to-bottom sheen,
///   3. a bright specular rim that fades round the edge, and
///   4. a soft, wide shadow so the element floats.
///
/// Set [blur] to 0 for long scrolling lists (cards): you keep the look of
/// the rim and sheen without a backdrop filter per row.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final ShapeBorder shape;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final double blur;
  final bool shadow;
  final double rimOpacity;

  const LiquidGlass({
    super.key,
    required this.child,
    this.shape = AppShapes.capsule,
    this.padding,
    this.tint = AppColors.glassFill,
    this.blur = 24,
    this.shadow = true,
    this.rimOpacity = 1,
  });

  /// Glass with iOS continuous corners of [radius].
  LiquidGlass.rounded({
    super.key,
    required this.child,
    required double radius,
    this.padding,
    this.tint = AppColors.glassFill,
    this.blur = 24,
    this.shadow = true,
    this.rimOpacity = 1,
  }) : shape = AppShapes.continuous(radius);

  static final List<double> _saturation = _saturationMatrix(1.8);

  static List<double> _saturationMatrix(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final inv = 1 - s;
    return <double>[
      r * inv + s, g * inv, b * inv, 0, 0,
      r * inv, g * inv + s, b * inv, 0, 0,
      r * inv, g * inv, b * inv + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sheenTop = Color.alphaBlend(Colors.white.withValues(alpha: 0.35), tint);

    Widget glass = CustomPaint(
      foregroundPainter: _GlassRimPainter(shape: shape, opacity: rimOpacity),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [sheenTop, tint, tint],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );

    if (blur > 0) {
      glass = BackdropFilter(
        filter: ui.ImageFilter.compose(
          outer: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          inner: ColorFilter.matrix(_saturation),
        ),
        child: glass,
      );
    }

    glass = ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      clipBehavior: Clip.antiAlias,
      child: glass,
    );

    if (!shadow) return glass;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: const [
          BoxShadow(
            color: AppColors.glassShadow,
            blurRadius: 30,
            spreadRadius: -6,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: glass,
    );
  }
}

/// Paints the specular rim: bright at the top-left where light "hits",
/// fading round the sides, with a faint catch-light on the bottom edge.
class _GlassRimPainter extends CustomPainter {
  final ShapeBorder shape;
  final double opacity;

  _GlassRimPainter({required this.shape, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect.deflate(0.6));

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.95 * opacity),
          Colors.white.withValues(alpha: 0.25 * opacity),
          Colors.white.withValues(alpha: 0.10 * opacity),
          Colors.white.withValues(alpha: 0.55 * opacity),
        ],
        stops: const [0, 0.35, 0.65, 1],
      ).createShader(rect);
    canvas.drawPath(path, rim);

    // Thin darker outline so glass stays defined on white backgrounds.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.black.withValues(alpha: 0.06 * opacity);
    canvas.drawPath(shape.getOuterPath(rect), outline);
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter old) =>
      old.shape != shape || old.opacity != opacity;
}

/// A round glass button, like iOS 26 navigation-bar buttons.
/// [prominent] tints it with the accent colour (e.g. "Done").
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool prominent;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.prominent = false,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final button = LiquidGlass(
      shape: AppShapes.circle,
      tint: prominent
          ? AppColors.primary.withValues(alpha: 0.92)
          : AppColors.glassFillStrong,
      rimOpacity: prominent ? 0.6 : 1,
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: onPressed,
          radius: size / 2,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: 20,
              color: prominent ? AppColors.onPrimary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Soft, colourful wash behind the app so the glass has something to show
/// through — flat grey behind glass just looks grey.
class AmbientBackground extends StatelessWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.background),
        const _Blob(alignment: Alignment(-1.2, -1.1), color: AppColors.ambientBlue, size: 420),
        const _Blob(alignment: Alignment(1.3, -0.35), color: AppColors.ambientPurple, size: 380),
        const _Blob(alignment: Alignment(-0.9, 1.15), color: AppColors.ambientTeal, size: 400),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final double size;

  const _Blob({required this.alignment, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small glass capsule for status chips and pill buttons.
class GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color tint;

  const GlassPill({
    super.key,
    required this.child,
    this.onTap,
    this.tint = AppColors.glassFillStrong,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      tint: tint,
      blur: 16,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: AppShapes.capsule,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 7,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
