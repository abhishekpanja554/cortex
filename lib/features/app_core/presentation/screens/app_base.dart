import 'package:cortex/core/native/battery_service.dart';
import 'package:cortex/core/theme/liquid_glass.dart';
import 'package:cortex/features/app_core/presentation/providers/providers.dart';
import 'package:cortex/features/app_core/presentation/widgets/glass_bottom_nav.dart';
import 'package:cortex/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:cortex/features/notes/presentation/screens/search_screen.dart';
import 'package:cortex/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppBase extends ConsumerStatefulWidget {
  const AppBase({super.key});

  @override
  ConsumerState<AppBase> createState() => _AppBaseState();
}

class _AppBaseState extends ConsumerState<AppBase> {
  // IndexedStack keeps each tab alive, so scroll position and the search
  // query survive switching tabs.
  static const List<Widget> _pages = [
    NotesListScreen(key: ValueKey('notes_list')),
    SearchScreen(key: ValueKey('search')),
    SettingsScreen(key: ValueKey('settings')),
  ];

  @override
  void initState() {
    super.initState();
    _checkBattery();
  }

  Future<void> _checkBattery() async {
    final batteryLevel = await BatteryService.getBatteryLevel();
    if (batteryLevel >= 0 && batteryLevel < 10 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Battery is at $batteryLevel% — your notes are saved automatically.'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(appStateProvider).currentTab;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: IndexedStack(index: currentTab, children: _pages),
      ),
      // Hide the floating tab bar while typing so it never sits on the keyboard.
      bottomNavigationBar: keyboardOpen
          ? null
          : GlassBottomNav(
              currentIndex: currentTab,
              onTap: (index) =>
                  ref.read(appStateProvider.notifier).changeTab(index),
            ),
    );
  }
}
