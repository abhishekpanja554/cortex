import 'package:cortex/core/constants/colors.dart';
import 'package:flutter/material.dart';

class PinPad extends StatefulWidget {
  final Function(String) onCompleted;
  final String title;
  final String? subtitle;
  final bool showCancel;
  final VoidCallback? onCancel;

  const PinPad({
    super.key,
    required this.onCompleted,
    this.title = "Enter PIN",
    this.subtitle,
    this.showCancel = false,
    this.onCancel,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = "";
  static const int _pinLength = 4;

  void _onKeyPress(String value) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += value;
      });
      if (_pin.length == _pinLength) {
        widget.onCompleted(_pin);
        // Clear pin after short delay to allow UI to show full pin dots if needed
        // but for now we just clear it so next attempt starts fresh
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _pin = "");
        });
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.subtitle!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pinLength, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < _pin.length
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.3),
              ),
            );
          }),
        ),
        const SizedBox(height: 50),
        _buildKeyboard(),
        if (widget.showCancel) ...[
          const SizedBox(height: 20),
          TextButton(
            onPressed: widget.onCancel,
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKeyboard() {
    return Column(
      children: [
        _buildRow(["1", "2", "3"]),
        _buildRow(["4", "5", "6"]),
        _buildRow(["7", "8", "9"]),
        _buildRow(["", "0", "backspace"]),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        if (key.isEmpty) {
          return const SizedBox(width: 80, height: 80);
        }
        if (key == "backspace") {
          return IconButton(
            onPressed: _onBackspace,
            icon: const Icon(Icons.backspace_outlined, color: Colors.white),
            iconSize: 28,
            constraints: const BoxConstraints.tightFor(width: 80, height: 80),
          );
        }
        return InkWell(
          onTap: () => _onKeyPress(key),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            child: Text(
              key,
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
