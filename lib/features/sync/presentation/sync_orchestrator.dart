import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hooks up UI-level sync triggers (app lifecycle, connectivity changes,
/// local edits, and pull-to-refresh) to the underlying [SyncScheduler].
class SyncOrchestrator extends ConsumerStatefulWidget {
  const SyncOrchestrator({required this.child, super.key});
  final Widget child;

  /// Lets descendant widgets report local edits or pull-to-refresh.
  static SyncOrchestratorState? of(BuildContext context) {
    return context.findAncestorStateOfType<SyncOrchestratorState>();
  }

  @override
  ConsumerState<SyncOrchestrator> createState() => SyncOrchestratorState();
}

class SyncOrchestratorState extends ConsumerState<SyncOrchestrator>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _editDebounce;
  bool _wasConnected = true;

  SyncScheduler get _scheduler => ref.read(syncSchedulerProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Ask scheduler to sync when network interface recovers
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (connected && !_wasConnected) {
        _scheduler.onNetworkBack();
      }
      _wasConnected = connected;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncIfAuthenticated();
    });
  }

  void _syncIfAuthenticated() {
    final authState = ref.read(authProvider);
    if (authState is Authenticated) {
      _scheduler.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _editDebounce?.cancel();
    super.dispose();
  }

  // App lifecycle: pause periodic timer in background, sync on resume
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduler.onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      _scheduler.onAppPaused();
    }
  }

  // Wait 3 seconds after the user stops typing before requesting a sync
  void onLocalEdit() {
    _editDebounce?.cancel();
    _editDebounce = Timer(const Duration(seconds: 3), () {
      _scheduler.requestSync();
    });
  }

  // Manual pull-to-refresh: requests sync and waits until current cycle finishes
  Future<void> onPullToRefresh() async {
    final completer = Completer<void>();
    StreamSubscription<SyncStatus>? sub;

    sub = _scheduler.statusStream.listen((status) {
      if (status is! SyncStatusSyncing) {
        completer.complete();
        sub?.cancel();
      }
    });

    _scheduler.requestSync();

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        sub?.cancel();
      },
    );
  }

  // Sync only while the user is logged in
  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is Authenticated) {
        _scheduler.start();
      } else {
        _scheduler.stop();
      }
    });

    return widget.child;
  }
}
