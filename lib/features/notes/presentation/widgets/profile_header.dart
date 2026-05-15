import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBackground,
              border: Border.all(color: AppColors.borderLight, width: 1.5),
            ),
            child: const Icon(Icons.person, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 12),

          // Name & subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Abhishek Panja', style: TextStyles.userNameStyle),
                const SizedBox(height: 2),
                Text('App Developer', style: TextStyles.userSubtitleStyle),
              ],
            ),
          ),

          // Settings icon
          _buildIconButton(Icons.settings_outlined),
          const SizedBox(width: 8),

          // Notification icon
          _buildIconButton(Icons.notifications_none_rounded),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Icon(icon, size: 20, color: AppColors.iconDefault),
    );
  }
}
