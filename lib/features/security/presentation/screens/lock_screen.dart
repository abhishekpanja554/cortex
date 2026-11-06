import 'package:cortex/features/security/presentation/widgets/pin_pad.dart';
import 'package:cortex/features/security/services/security_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cortex/core/providers/core_providers.dart';

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
  SecurityService get _securityService => ref.read(securityServiceProvider);
  bool _isPrivateModeEnabled = false;
  bool _isDeviceSecurityAvailable = false;
  bool _showPinPad = false;
  String? _pinError;

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
          _isAuthenticated = true;
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
        if (!success && _isDeviceSecurityAvailable) {}
      });
    }
  }

  Future<void> _onPinEntered(String pin) async {
    final isValid = await _securityService.verifyAppPin(pin);
    if (mounted) {
      setState(() {
        if (isValid) {
          _isAuthenticated = true;
          _showPinPad = false;
          _pinError = null;
        } else {
          _pinError = 'Incorrect PIN. Try again.';
        }
      });
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

          // Fully opaque: locked notes must not be readable behind the lock.
          Positioned.fill(
            child: LockBackdrop(
              child: SafeArea(
                child: Center(
                  child: _showPinPad ? _buildPinEntry() : _buildDeviceAuth(),
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
            title: 'Cortex is locked',
            subtitle: 'Enter your app PIN to unlock',
            errorText: _pinError,
          ),
          if (_isDeviceSecurityAvailable) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => setState(() => _showPinPad = false),
              child: const Text(
                'Use Face ID / fingerprint',
                style: TextStyle(color: Colors.white70),
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
        const Icon(CupertinoIcons.lock_fill, size: 56, color: Colors.white),
        const SizedBox(height: 20),
        const Text(
          'Cortex is locked',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 40),
        if (_isAuthenticating)
          const CupertinoActivityIndicator(color: Colors.white, radius: 14)
        else
          SizedBox(
            width: 200,
            child: FilledButton.icon(
              onPressed: _authenticate,
              icon: const Icon(CupertinoIcons.lock_open_fill),
              label: const Text('Unlock'),
            ),
          ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() => _showPinPad = true),
          child: const Text(
            'Use app PIN',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}
