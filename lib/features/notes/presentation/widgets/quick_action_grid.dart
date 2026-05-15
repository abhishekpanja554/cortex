import 'dart:ui';

import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:flutter/material.dart';

class QuickActionGrid extends StatefulWidget {
  final VoidCallback? onTextNoteTap;

  const QuickActionGrid({super.key, this.onTextNoteTap});

  @override
  State<QuickActionGrid> createState() => _QuickActionGridState();
}

class _QuickActionGridState extends State<QuickActionGrid> {
  int _selectedIndex = 1; // Voice Note selected by default

  static const _actions = [
    (
      icon: Icons.text_fields_rounded,
      title: AppStrings.textNote,
      subtitle: AppStrings.textNoteDesc,
    ),
    (
      icon: Icons.mic_rounded,
      title: AppStrings.voiceNote,
      subtitle: AppStrings.voiceNoteDesc,
    ),
    (
      icon: Icons.image_outlined,
      title: AppStrings.imageNote,
      subtitle: AppStrings.imageNoteDesc,
    ),
    (
      icon: Icons.auto_awesome_outlined,
      title: AppStrings.aiNote,
      subtitle: AppStrings.aiNoteDesc,
    ),
  ];

  void _onCardTap(int index) {
    setState(() => _selectedIndex = index);

    // Navigate for Text Note (index 0)
    if (index == 0) {
      widget.onTextNoteTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _actions.length,
        itemBuilder: (context, index) {
          final action = _actions[index];
          final isSelected = index == _selectedIndex;
          return GestureDetector(
            onTap: () => _onCardTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: _QuickActionCard(
                icon: action.icon,
                title: action.title,
                subtitle: action.subtitle,
                isFeatured: isSelected,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isFeatured;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isFeatured,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: isFeatured
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.voiceNoteStart.withValues(alpha: 0.85),
                      AppColors.voiceNoteEnd.withValues(alpha: 0.75),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.65),
                      Colors.white.withValues(alpha: 0.40),
                    ],
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFeatured
                  ? Colors.white.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.60),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isFeatured
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: isFeatured ? 0.10 : 0.50),
                blurRadius: 1,
                spreadRadius: 0,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container — frosted inner glass
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isFeatured
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: isFeatured ? 0.25 : 0.70,
                    ),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isFeatured ? Colors.white : AppColors.primary,
                ),
              ),
              const Spacer(),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: isFeatured
                    ? TextStyles.quickActionTitleWhite
                    : TextStyles.quickActionTitle,
                child: Text(title),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: isFeatured
                    ? TextStyles.quickActionSubtitleWhite
                    : TextStyles.quickActionSubtitle,
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
