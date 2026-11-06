import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/features/security/presentation/widgets/pin_pad.dart';
import 'package:flutter/material.dart';

/// Full-screen "create PIN → confirm PIN" flow. Pops with the PIN, or null
/// when cancelled.
class PinSetupDialog extends StatefulWidget {
  const PinSetupDialog({super.key});

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  String? _firstPin;
  String? _error;

  bool get _isConfirming => _firstPin != null;

  void _onPinCompleted(String pin) {
    if (!_isConfirming) {
      setState(() {
        _firstPin = pin;
        _error = null;
      });
    } else if (pin == _firstPin) {
      Navigator.of(context).pop(pin);
    } else {
      setState(() {
        _firstPin = null;
        _error = 'PINs didn’t match. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lockBackground,
      body: LockBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: PinPad(
                key: ValueKey(_isConfirming),
                title: _isConfirming ? 'Confirm PIN' : 'Set App PIN',
                subtitle: _isConfirming
                    ? 'Enter the same 4 digits again'
                    : 'Used to unlock Cortex when biometrics aren’t available',
                errorText: _error,
                onCompleted: _onPinCompleted,
                showCancel: true,
                onCancel: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
