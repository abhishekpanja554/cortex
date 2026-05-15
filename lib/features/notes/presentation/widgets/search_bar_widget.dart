import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final ValueChanged<String>? onChanged;

  const SearchBarWidget({super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.searchBarBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: AppColors.iconLight,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: onChanged,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: AppStrings.searchHint,
                  hintStyle: TextStyles.searchHintStyle,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const Icon(
              Icons.mic_none_rounded,
              color: AppColors.iconDefault,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
