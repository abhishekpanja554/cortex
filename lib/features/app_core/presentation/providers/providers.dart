import 'package:cortex/features/app_core/presentation/notifiers/app_notifier.dart';
import 'package:cortex/features/app_core/presentation/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appStateProvider = NotifierProvider<AppNotifier, AppState>(
  AppNotifier.new,
);
