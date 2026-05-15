import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/features/app_core/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:cortex/features/settings/presentation/screens/settings_screen.dart';
import 'package:cortex/features/app_core/presentation/widgets/glass_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppBase extends ConsumerStatefulWidget {
  const AppBase({super.key});

  @override
  ConsumerState<AppBase> createState() => _AppBaseState();
}

class _AppBaseState extends ConsumerState<AppBase> {
  final List<Widget> _pages = [
    const NotesListScreen(),
    const Center(child: Text(AppStrings.business)),
    const SettingsScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(appStateProvider).currentTab;
    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,

      extendBody: true,
      body: Stack(
        children: [
          _pages[currentTab],
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassBottomNav(
              currentIndex: currentTab,
              onTap: (index) =>
                  ref.read(appStateProvider.notifier).changeTab(index),
            ),
          ),
        ],
      ),
    );
  }
}
