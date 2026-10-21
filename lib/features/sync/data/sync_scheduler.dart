import 'dart:async';
import 'package:cortex/features/sync/data/sync_engine.dart';
import 'package:cortex/features/sync/domain/sync_failure.dart';

// Single sync scheduler. All triggers call requestSync(),
// and this decides when syncOnce actually executes.
//
// Rules:
// - At most one sync runs at a time.
// - Multiple requests while running collapse into one follow-up sync.
// - Exponential backoff on failure (5s -> 5m max).
// - NetworkUnavailable skips timer retries (waits for network-back trigger).
// - Stops everything on logout.
class SyncScheduler {
  SyncScheduler({required SyncEngine syncEngine}) : _syncEngine = syncEngine;

  final SyncEngine _syncEngine;

  bool _running = false;
  bool _pendingFollowUp = false;
  bool _stopped = true;
  bool _networkDown = false;

  int _consecutiveFailures = 0;
  Timer? _retryTimer;
  Timer? _periodicTimer;

  DateTime? _lastSuccessfulSync;

  bool get isSyncing => _running;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  // Lifecycle

  void start() {
    _stopped = false;
    _consecutiveFailures = 0;
    _networkDown = false;
    _startPeriodicTimer();
    requestSync();
  }

  void stop() {
    _stopped = true;
    _pendingFollowUp = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _lastSuccessfulSync = null;
    _consecutiveFailures = 0;
    _statusController.add(SyncStatus.idle);
  }

  void dispose() {
    stop();
    _statusController.close();
  }

  // Triggers

  void requestSync() {
    if (_stopped) return;

    if (_running) {
      // 5 requests during a sync = 1 follow-up, not 5
      _pendingFollowUp = true;
      return;
    }

    _run();
  }

  void requestSyncOnResume({
    Duration minInterval = const Duration(seconds: 30),
  }) {
    if (_stopped) return;
    final last = _lastSuccessfulSync;
    if (last != null && DateTime.now().difference(last) < minInterval) {
      return;
    }
    requestSync();
  }

  // Network back is just a hint from connectivity_plus
  void onNetworkBack() {
    if (_stopped) return;
    _networkDown = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    requestSync();
  }

  // Internal loop

  Future<void> _run() async {
    if (_stopped || _running) return;

    _running = true;
    _pendingFollowUp = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _statusController.add(SyncStatus.syncing);

    try {
      await _syncEngine.syncOnce();
      _onSuccess();
    } on SyncFailure catch (e) {
      _onFailure(e);
    } catch (e) {
      _onFailure(UnknownSyncFailure(e));
    }
  }

  void _onSuccess() {
    _running = false;
    _consecutiveFailures = 0;
    _lastSuccessfulSync = DateTime.now();
    _statusController.add(SyncStatus.idle);

    if (_pendingFollowUp && !_stopped) {
      _pendingFollowUp = false;
      _run();
    }
  }

  void _onFailure(SyncFailure failure) {
    _running = false;
    _consecutiveFailures++;
    _statusController.add(SyncStatus.error(failure));

    if (_stopped) return;

    if (failure is SessionExpiredSyncFailure) {
      stop();
      return;
    }

    if (failure is NetworkUnavailableSyncFailure) {
      _networkDown = true;
      _pendingFollowUp = false;
      // Interface might be down, or server might be unreachable while Wi-Fi is fine.
      // Keep a slow 5-minute retry so it recovers even without a connectivity change.
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(minutes: 5), () {
        if (!_stopped) {
          _networkDown = false;
          _run();
        }
      });
      return;
    }

    // Backoff: 5s, 10s, 20s, 40s... capped at 5 minutes
    final delay = _retryDelay();
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_stopped) {
        _run();
      }
    });
  }

  Duration _retryDelay() {
    final seconds = 5 * (1 << (_consecutiveFailures - 1).clamp(0, 6));
    return Duration(seconds: seconds.clamp(5, 300));
  }

  // Periodic foreground sync (every 2 min)

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!_stopped && !_networkDown) {
        requestSync();
      }
    });
  }

  void onAppResumed() {
    if (_stopped) return;
    _startPeriodicTimer();
    requestSyncOnResume();
  }

  void onAppPaused() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
}

// Sync UI status

sealed class SyncStatus {
  const SyncStatus();

  static const idle = SyncStatusIdle();
  static const syncing = SyncStatusSyncing();
  static SyncStatus error(SyncFailure failure) => SyncStatusError(failure);
}

class SyncStatusIdle extends SyncStatus {
  const SyncStatusIdle();
}

class SyncStatusSyncing extends SyncStatus {
  const SyncStatusSyncing();
}

class SyncStatusError extends SyncStatus {
  final SyncFailure failure;
  const SyncStatusError(this.failure);
}
