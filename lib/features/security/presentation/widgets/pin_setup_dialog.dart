import 'package:cortex/features/security/presentation/widgets/pin_pad.dart';
import 'package:flutter/material.dart';

class PinSetupDialog extends StatefulWidget {
  const PinSetupDialog({super.key});

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  String? _firstPin;
  bool _isConfirming = false;

  void _onPinCompleted(String pin) {
    if (!_isConfirming) {
      setState(() {
        _firstPin = pin;
        _isConfirming = true;
      });
    } else {
      if (pin == _firstPin) {
        Navigator.of(context).pop(pin);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PINs do not match. Try again.")),
        );
        setState(() {
          _firstPin = null;
          _isConfirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: SingleChildScrollView(
          child: PinPad(
            title: _isConfirming ? "Confirm PIN" : "Set App PIN",
            subtitle: _isConfirming
                ? "Re-enter your PIN to confirm"
                : "Create a 4-digit PIN for Cortex",
            onCompleted: _onPinCompleted,
            showCancel: true,
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
