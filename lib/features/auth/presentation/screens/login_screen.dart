import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/features/auth/domain/auth_failure.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/auth/presentation/widgets/auth_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError(String _) {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your email and password.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).login(email, password);
      TextInput.finishAutofillContext();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _errorMessage = messageForAuthFailure(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final sessionExpired = authState is Unauthenticated &&
        authState.reason == LogoutReason.sessionExpired;

    return AuthLayout(
      icon: CupertinoIcons.square_pencil,
      title: 'Welcome Back',
      subtitle: 'Log in to continue to Cortex',
      form: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sessionExpired) ...[
              const AuthMessage(
                message: 'Your session expired. Please log in again.',
                isWarning: true,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            AuthField(
              controller: _emailController,
              label: 'Email',
              hint: 'you@example.com',
              icon: CupertinoIcons.mail,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              onChanged: _clearError,
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Your password',
              icon: CupertinoIcons.lock,
              isPassword: true,
              enabled: !_isSubmitting,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onChanged: _clearError,
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_errorMessage != null) ...[
              AuthMessage(message: _errorMessage!),
              const SizedBox(height: AppSpacing.lg),
            ],
            AuthSubmitButton(label: 'Log in', busy: _isSubmitting, onPressed: _login),
          ],
        ),
      ),
      footer: AuthFooterLink(
        prompt: 'Don’t have an account?',
        action: 'Register',
        onPressed: _isSubmitting ? null : () => context.go('/register'),
      ),
    );
  }
}
