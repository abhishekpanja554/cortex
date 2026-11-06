import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/theme/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS inset-grouped list section: a glass card of [SettingsTile]s with
/// hairline separators inset past the icon, like the iOS Settings app.
class SettingsGroup extends StatelessWidget {
  final String? title;
  final String? footer;
  final List<Widget> children;

  const SettingsGroup({super.key, this.title, this.footer, required this.children});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(const Divider(indent: 60));
      }
      items.add(children[i]);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Untitled groups still get the same gap above them as titled ones.
          if (title == null) const SizedBox(height: AppSpacing.xxl + AppSpacing.xs),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.sm - 2,
              ),
              child: Text(title!.toUpperCase(), style: TextStyles.caption),
            ),
          LiquidGlass.rounded(
            radius: AppRadius.xl,
            tint: AppColors.glassFillStrong,
            blur: 0,
            child: Material(
              type: MaterialType.transparency,
              child: Column(children: items),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm - 2,
                AppSpacing.lg,
                0,
              ),
              child: Text(footer!, style: TextStyles.caption),
            ),
        ],
      ),
    );
  }
}

/// A Settings-style row: white glyph on a coloured continuous-corner tile,
/// title/subtitle, and a trailing control or chevron.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor = AppColors.primary,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              IconTile(icon: icon, color: destructive ? AppColors.red : iconColor),
              const SizedBox(width: AppSpacing.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyles.body.copyWith(
                        color: destructive ? AppColors.red : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!, style: TextStyles.caption),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ] else if (onTap != null && !destructive)
                const Icon(
                  CupertinoIcons.chevron_forward,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White glyph on a 30pt continuous-corner colour tile (iOS Settings icon).
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconTile({super.key, required this.icon, required this.color, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(size * 0.27),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.18)!, color],
        ),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: size * 0.6, color: Colors.white),
      ),
    );
  }
}
