import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl + AppSpacing.sm,
        vertical: AppSpacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 52),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: TextStyles.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(message, style: TextStyles.bodySecondary, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
