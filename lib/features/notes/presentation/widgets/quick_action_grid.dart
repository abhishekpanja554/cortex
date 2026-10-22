import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/theme/liquid_glass.dart';
import 'package:cortex/features/notes/domain/note_template.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// "Create" row on the home tab: three glass tiles, each opening the editor
/// in a real, working mode.
class QuickActionGrid extends StatelessWidget {
  final ValueChanged<NoteTemplate> onSelected;

  const QuickActionGrid({super.key, required this.onSelected});

  static const _actions = [
    (template: NoteTemplate.text, icon: CupertinoIcons.square_pencil, label: AppStrings.textNote),
    (template: NoteTemplate.checklist, icon: CupertinoIcons.checkmark_square, label: AppStrings.checklistNote),
    (template: NoteTemplate.image, icon: CupertinoIcons.photo_on_rectangle, label: AppStrings.imageNote),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          for (var i = 0; i < _actions.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md - 2),
            Expanded(
              child: _QuickActionTile(
                icon: _actions[i].icon,
                label: _actions[i].label,
                prominent: i == 0,
                onTap: () => onSelected(_actions[i].template),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool prominent;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.prominent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = prominent ? AppColors.onPrimary : AppColors.primary;
    return LiquidGlass.rounded(
      radius: AppRadius.xl,
      tint: prominent
          ? AppColors.primary.withValues(alpha: 0.9)
          : AppColors.glassFill,
      rimOpacity: prominent ? 0.7 : 1,
      blur: 20,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg + 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fg, size: 28),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  style: TextStyles.label.copyWith(
                    color: prominent ? fg : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
