import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS large-title navigation bar used at the top of every tab.
///
/// The 34pt title collapses into a small centred title as you scroll, and
/// the bar turns into frosted glass only once content is underneath it —
/// exactly like Notes, Mail or Settings on iOS.
class AppLargeTitleBar extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const AppLargeTitleBar({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverNavigationBar(
      largeTitle: Text(title),
      trailing: trailing,
      automaticallyImplyLeading: false,
      // Three tabs live in one route; route transitions would make their
      // Hero tags collide.
      transitionBetweenRoutes: false,
      backgroundColor: AppColors.background.withValues(alpha: 0.7),
      border: const Border(
        bottom: BorderSide(color: AppColors.border, width: 0.5),
      ),
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.page),
    );
  }
}

/// Header above a group of content ("Create", "Recent").
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page + AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.page + AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(text, style: TextStyles.title)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
