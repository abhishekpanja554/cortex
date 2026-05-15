import 'dart:ui';
import 'package:cortex/core/constants/colors.dart';
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
    final isEnabled = await _securityService.isPrivateModeEnabled;
    if (mounted) {
      setState(() {
        _isPrivateModeEnabled = isEnabled;
        if (!isEnabled) {
          _isAuthenticated = true; // No auth needed
        }
      });
      if (isEnabled && !_isAuthenticated && !_isAuthenticating) {
        _authenticate();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isPrivateModeEnabled && !_isAuthenticated && !_isAuthenticating) {
        _authenticate();
      }
    } else if (state == AppLifecycleState.paused) {
      if (_isPrivateModeEnabled) {
        setState(() {
          _isAuthenticated = false;
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

          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
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
                          const CircularProgressIndicator(
                            color: AppColors.primary,
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _authenticate,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text("Unlock"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
