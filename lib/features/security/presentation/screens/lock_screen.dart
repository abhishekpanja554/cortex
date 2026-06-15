import 'dart:ui';
import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/features/security/presentation/widgets/pin_pad.dart';
import 'package:cortex/features/security/services/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LockScreen extends ConsumerStatefulWidget {
  final Widget child;

  const LockScreen({super.key, required this.child});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  final SecurityService _securityService = SecurityService();
  bool _isPrivateModeEnabled = false;
  bool _isDeviceSecurityAvailable = false;
  bool _showPinPad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPrivateMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkPrivateMode() async {
    await _securityService.syncPrivacyState();
    final isEnabled = await _securityService.isPrivateModeEnabled;
    final isDeviceSecurityAvailable =
        await _securityService.isDeviceSecurityAvailable;

    if (mounted) {
      setState(() {
        _isPrivateModeEnabled = isEnabled;
        _isDeviceSecurityAvailable = isDeviceSecurityAvailable;
        if (!isEnabled) {
          _isAuthenticated = true; // No auth needed
        } else if (!isDeviceSecurityAvailable) {
          _showPinPad = true;
        }
      });

      if (isEnabled &&
          !_isAuthenticated &&
          !_isAuthenticating &&
          isDeviceSecurityAvailable) {
        _authenticate();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isPrivateModeEnabled && !_isAuthenticated && !_isAuthenticating) {
        if (_isDeviceSecurityAvailable) {
          _authenticate();
        } else {
          setState(() {
            _showPinPad = true;
          });
        }
      }
    } else if (state == AppLifecycleState.paused) {
      if (_isPrivateModeEnabled) {
        setState(() {
          _isAuthenticated = false;
          _showPinPad = !_isDeviceSecurityAvailable;
        });
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    final success = await _securityService.authenticate();

    if (mounted) {
      setState(() {
        _isAuthenticated = success;
        _isAuthenticating = false;
        if (!success && _isDeviceSecurityAvailable) {
          // If biometric fails, user might want to use PIN
          // but we only show PIN if they have one
        }
      });
    }
  }

  Future<void> _onPinEntered(String pin) async {
    final isValid = await _securityService.verifyAppPin(pin);
    if (mounted) {
      if (isValid) {
        setState(() {
          _isAuthenticated = true;
          _showPinPad = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Incorrect PIN"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPrivateModeEnabled || _isAuthenticated) {
      return widget.child;
    }

    return Scaffold(
      body: Stack(
        children: [
          widget.child,

          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: Center(
                    child: _showPinPad ? _buildPinEntry() : _buildDeviceAuth(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinEntry() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PinPad(
            onCompleted: _onPinEntered,
            title: "Cortex is Locked",
            subtitle: "Enter your app PIN to unlock",
          ),
          if (_isDeviceSecurityAvailable) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => setState(() => _showPinPad = false),
              child: const Text(
                "Use Biometrics",
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceAuth() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 64, color: Colors.white),
        const SizedBox(height: 20),
        const Text(
          "Cortex is Locked",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 40),
        if (_isAuthenticating)
          const CircularProgressIndicator(color: AppColors.primary)
        else
          ElevatedButton.icon(
            onPressed: _authenticate,
            icon: const Icon(Icons.fingerprint),
            label: const Text("Unlock"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() => _showPinPad = true),
          child: const Text(
            "Use App PIN",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}
