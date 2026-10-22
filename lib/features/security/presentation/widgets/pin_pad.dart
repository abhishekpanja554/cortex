import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/theme/app_shapes.dart';
import 'package:cortex/core/theme/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 4-digit PIN entry used by both the lock screen and PIN setup, on the
/// dark [AppColors.lockBackground].
class PinPad extends StatefulWidget {
  final ValueChanged<String> onCompleted;
  final String title;
  final String? subtitle;
  final String? errorText;
  final bool showCancel;
  final VoidCallback? onCancel;

  const PinPad({
    super.key,
    required this.onCompleted,
    this.title = 'Enter PIN',
    this.subtitle,
    this.errorText,
    this.showCancel = false,
    this.onCancel,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  static const int _pinLength = 4;
  static const Map<String, String> _letters = {
    '1': '', '2': 'ABC', '3': 'DEF', '4': 'GHI', '5': 'JKL',
    '6': 'MNO', '7': 'PQRS', '8': 'TUV', '9': 'WXYZ', '0': '',
  };
  String _pin = '';

  void _onKeyPress(String value) {
    if (_pin.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += value);
    if (_pin.length == _pinLength) {
      final completed = _pin;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _pin = '');
        widget.onCompleted(completed);
      });
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.35,
            color: Colors.white,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 15,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxxl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pinLength, (index) {
            final filled = index < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: Colors.white.withValues(alpha: filled ? 1 : 0.6),
                  width: 1.5,
                ),
              ),
            );
          }),
        ),
        SizedBox(
          height: 40,
          child: Center(
            child: widget.errorText == null
                ? null
                : Text(
                    widget.errorText!,
                    style: const TextStyle(
                      color: Color(0xFFFF8A80),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
        _buildRow(const ['1', '2', '3']),
        _buildRow(const ['4', '5', '6']),
        _buildRow(const ['7', '8', '9']),
        _buildRow(const ['', '0', 'backspace']),
        if (widget.showCancel) ...[
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Cancel'),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys.map((key) {
          Widget child;
          if (key.isEmpty) {
            child = const SizedBox.shrink();
          } else if (key == 'backspace') {
            // No tooltip: the lock screen sits above the Navigator's Overlay.
            child = IconButton(
              onPressed: _onBackspace,
              icon: const Icon(CupertinoIcons.delete_left, color: Colors.white, size: 26),
            );
          } else {
            child = LiquidGlass(
              shape: AppShapes.circle,
              tint: Colors.white.withValues(alpha: 0.10),
              blur: 0,
              shadow: false,
              rimOpacity: 0.45,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  highlightColor: Colors.white.withValues(alpha: 0.25),
                  onTap: () => _onKeyPress(key),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        key,
                        style: const TextStyle(
                          fontSize: 34,
                          height: 1.1,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (_letters[key]!.isNotEmpty)
                        Text(
                          _letters[key]!,
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(width: 78, height: 78, child: child),
          );
        }).toList(),
      ),
    );
  }
}

/// Dark, softly-lit backdrop behind the lock and PIN screens so the glass
/// keys have depth (iOS passcode screens sit on a blurred wallpaper).
class LockBackdrop extends StatelessWidget {
  final Widget child;
  const LockBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.6, -0.9),
          radius: 1.6,
          colors: [Color(0xFF1E2A4A), Color(0xFF141526), AppColors.lockBackground],
          stops: [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}
