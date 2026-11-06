import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/features/auth/domain/auth_failure.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/auth/presentation/widgets/auth_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _minPasswordLength = 8;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _emailTaken = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError(String _) {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
        _emailTaken = false;
      });
    }
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }
    if (password.length < _minPasswordLength) {
      setState(() => _errorMessage =
          'Password must be at least $_minPasswordLength characters.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _emailTaken = false;
    });

    try {
      await ref.read(authProvider.notifier).register(email, password);
      TextInput.finishAutofillContext();
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = messageForAuthFailure(e);
          _emailTaken = e is EmailAlreadyInUse;
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      icon: CupertinoIcons.person_badge_plus,
      title: 'Create Account',
      subtitle: 'Sign up to start using Cortex',
      form: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              controller: _emailController,
              label: 'Email',
              hint: 'you@example.com',
              icon: CupertinoIcons.mail,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: _clearError,
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthField(
              controller: _passwordController,
              label: 'Password',
              hint: 'At least $_minPasswordLength characters',
              icon: CupertinoIcons.lock,
              isPassword: true,
              enabled: !_isSubmitting,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: _clearError,
              onSubmitted: (_) => _register(),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_errorMessage != null) ...[
              AuthMessage(
                message: _errorMessage!,
                action: _emailTaken
                    ? TextButton(
                        onPressed: () => context.go('/login'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Log in instead'),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AuthSubmitButton(
              label: 'Create account',
              busy: _isSubmitting,
              onPressed: _register,
            ),
          ],
        ),
      ),
      footer: AuthFooterLink(
        prompt: 'Already have an account?',
        action: 'Log in',
        onPressed: _isSubmitting ? null : () => context.go('/login'),
      ),
    );
  }
}
