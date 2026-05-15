import 'dart:ui';
import 'package:cortex/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  GlassBottomNav({super.key, required this.currentIndex, required this.onTap});

  final List _icons = [
    HugeIcons.strokeRoundedHome04,
    HugeIcons.strokeRoundedNote02,
    HugeIcons.strokeRoundedSettings01,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30, left: 40, right: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              color: Colors.black87.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / _icons.length;
                final highlightLeftOffset = currentIndex * itemWidth;

                return Stack(
                  children: [
                    // Sliding blue highlight
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      left: highlightLeftOffset,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: Center(
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),

                    // Icons Row
                    Row(
                      children: List.generate(_icons.length, (index) {
                        final isSelected = currentIndex == index;
                        return SizedBox(
                          width: itemWidth,
                          child: GestureDetector(
                            onTap: () => onTap(index),
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.transparent
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: HugeIcon(
                                    icon: _icons[index],
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
