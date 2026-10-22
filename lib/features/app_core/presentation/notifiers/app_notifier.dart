import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';

class AppNotifier extends Notifier<AppState> {
  static const int notesTab = 0;
  static const int searchTab = 1;
  static const int settingsTab = 2;

  @override
  AppState build() {
    // Rebuilds (and so resets to the Notes tab) whenever the user logs in or
    // out — otherwise a fresh login lands on whatever tab was open at logout.
    ref.watch(authProvider.select((s) => s is Authenticated));
    return const AppState(currentTab: notesTab);
  }

  void changeTab(int tab) {
    if (tab == state.currentTab) return;
    state = AppState(currentTab: tab);
  }
}
