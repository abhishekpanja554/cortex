import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/theme/app_shapes.dart';
import 'package:cortex/core/theme/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

/// iOS 26-style floating tab bar: a Liquid Glass capsule whose selected tab
/// sits in a lighter glass "lens" that slides between items.
///
/// Used as `Scaffold.bottomNavigationBar` with `extendBody: true`, so the
/// Scaffold reports its height via `MediaQuery.padding.bottom`.
class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(CupertinoIcons.doc_text, CupertinoIcons.doc_text_fill, 'Notes'),
    _NavItem(CupertinoIcons.search, CupertinoIcons.search, 'Search'),
    _NavItem(CupertinoIcons.gear_alt, CupertinoIcons.gear_alt_fill, 'Settings'),
  ];

  static const double _itemWidth = 88;
  static const double _height = 62;
  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Center(
        heightFactor: 1,
        child: LiquidGlass(
          blur: 28,
          child: SizedBox(
            height: _height,
            width: _itemWidth * _items.length + _inset * 2,
            child: Padding(
              padding: const EdgeInsets.all(_inset),
              child: Stack(
                children: [
                  // Sliding selection lens.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    left: currentIndex * _itemWidth,
                    top: 0,
                    bottom: 0,
                    width: _itemWidth,
                    child: const LiquidGlass(
                      shape: AppShapes.capsule,
                      tint: Color(0x1F007AFF),
                      blur: 0,
                      shadow: false,
                      rimOpacity: 0.9,
                      child: SizedBox.expand(),
                    ),
                  ),
                  Row(
                    children: List.generate(_items.length, (index) {
                      final item = _items[index];
                      final selected = index == currentIndex;
                      final color =
                          selected ? AppColors.primary : AppColors.textPrimary;
                      return SizedBox(
                        width: _itemWidth,
                        child: Semantics(
                          button: true,
                          selected: selected,
                          label: item.label,
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (!selected) HapticFeedback.selectionClick();
                              onTap(index);
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  selected ? item.activeIcon : item.icon,
                                  size: 24,
                                  color: color,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
