import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';

class AppNotifier extends Notifier<AppState> {
  @override
  AppState build() {
    return const AppState(currentTab: 0);
  }

  void changeTab(int tab) {
    state = AppState(currentTab: tab);
  }
}
