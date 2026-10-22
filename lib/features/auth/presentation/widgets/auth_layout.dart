import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/theme/app_shapes.dart';
import 'package:cortex/core/theme/app_theme.dart';
import 'package:cortex/core/theme/liquid_glass.dart';
import 'package:cortex/features/auth/domain/auth_failure.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shared shell for Login and Register so both screens are pixel-identical
/// apart from their copy and fields.
class AuthLayout extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;

  const AuthLayout({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xxxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: LiquidGlass.rounded(
                        radius: AppRadius.xl,
                        tint: AppColors.glassFillStrong,
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: Icon(icon, size: 40, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(title, style: TextStyles.display, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      subtitle,
                      style: TextStyles.bodySecondary.copyWith(fontSize: 17),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    LiquidGlass.rounded(
                      radius: AppRadius.xxl,
                      blur: 30,
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Material(
                        type: MaterialType.transparency,
                        child: form,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Labelled input used by the auth forms. Password fields get a show/hide
/// toggle.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: widget.isPassword && _obscured,
          autocorrect: false,
          enableSuggestions: !widget.isPassword,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: TextStyles.body.copyWith(fontSize: 15, height: 1.2),
          decoration: AppTheme.fieldDecoration(
            hintText: widget.hint,
            prefixIcon: widget.icon,
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscured ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                      size: 20,
                    ),
                    color: AppColors.textTertiary,
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Inline message banner (error or warning) for the auth forms.
class AuthMessage extends StatelessWidget {
  final String message;
  final bool isWarning;
  final Widget? action;

  const AuthMessage({super.key, required this.message, this.isWarning = false, this.action});

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppColors.warning : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: ShapeDecoration(
        color: isWarning ? AppColors.warningSoft : AppColors.dangerSoft,
        shape: AppShapes.continuous(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning
                ? CupertinoIcons.exclamationmark_triangle_fill
                : CupertinoIcons.exclamationmark_circle_fill,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (action != null) action!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Don't have an account? Register" style footer link.
class AuthFooterLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback? onPressed;

  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: TextStyles.bodySecondary),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}

/// Primary submit button with an inline spinner while busy.
class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const CupertinoActivityIndicator(color: Colors.white)
          : Text(label),
    );
  }
}

/// User-facing copy for every auth failure, shared by Login and Register.
String messageForAuthFailure(AuthFailure failure) => switch (failure) {
      InvalidCredentials() => 'Incorrect email or password.',
      NetworkUnavailable() => 'Can’t reach Cortex. Check your connection and try again.',
      EmailAlreadyInUse() => 'An account with this email already exists.',
      ValidationFailed(message: final msg) => msg,
      ServerError(status: final status, requestId: final reqId) =>
        'Something went wrong on our side (ref: ${reqId ?? status ?? 'unknown'}).',
      SessionExpired() => 'Your session expired. Please log in again.',
    };
