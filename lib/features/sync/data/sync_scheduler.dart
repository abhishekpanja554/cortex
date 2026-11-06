import 'dart:async';
import 'dart:developer' as developer;
import 'package:clock/clock.dart';
import 'package:cortex/features/sync/data/sync_engine.dart';
import 'package:cortex/features/sync/domain/sync_failure.dart';

enum SyncTrigger {
  startup,
  manual,
  noteDeleted,
  noteRestored,
  undoWindowExpired,
  periodic,
  appResume,
  networkBack,
  retry,
}

class SyncRunLog {
  final DateTime timestamp;
  final SyncTrigger trigger;
  final Duration duration;
  final int skippedTombstones;
  final int pushedCount;
  final int pulledCount;
  final Object? error;
  final bool success;

  const SyncRunLog({
    required this.timestamp,
    required this.trigger,
    required this.duration,
    required this.skippedTombstones,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.error,
    this.success = true,
  });

  @override
  String toString() {
    final status = success
        ? 'SUCCESS (pushed=$pushedCount, pulled=$pulledCount)'
        : 'FAILED ($error)';
    return '[SyncRun] trigger=${trigger.name}, skippedTombstones=$skippedTombstones, duration=${duration.inMilliseconds}ms, status=$status';
  }
}

// Single sync scheduler. All triggers call requestSync(),
// and this decides when syncOnce actually executes.
//
// Rules:
// - At most one sync runs at a time.
// - Multiple requests while running collapse into one follow-up sync.
// - Exponential backoff on failure (5s -> 5m max).
// - NetworkUnavailable skips timer retries (waits for network-back trigger).
// - Owns the undo window: schedules a timer when tombstones are skipped.
// - Stops everything on logout.
class SyncScheduler {
  SyncScheduler({required SyncEngine syncEngine}) : _syncEngine = syncEngine;

  final SyncEngine _syncEngine;

  bool _running = false;
  bool _pendingFollowUp = false;
  SyncTrigger? _pendingTrigger;
  bool _stopped = true;
  bool _networkDown = false;

  int _consecutiveFailures = 0;
  Timer? _retryTimer;
  Timer? _periodicTimer;
  Timer? _tombstoneTimer;

  DateTime? _lastSuccessfulSync;

  bool get isSyncing => _running;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  final _recentLogs = <SyncRunLog>[];
  List<SyncRunLog> get recentLogs => List.unmodifiable(_recentLogs);

  // Lifecycle

  void start() {
    _stopped = false;
    _consecutiveFailures = 0;
    _networkDown = false;
    _startPeriodicTimer();
    requestSync(SyncTrigger.startup);
  }

  void stop() {
    _stopped = true;
    _pendingFollowUp = false;
    _pendingTrigger = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _tombstoneTimer?.cancel();
    _tombstoneTimer = null;
    _lastSuccessfulSync = null;
    _consecutiveFailures = 0;
    _statusController.add(SyncStatus.idle);
  }

  void dispose() {
    stop();
    _statusController.close();
  }

  // Triggers

  void requestSync([SyncTrigger trigger = SyncTrigger.manual]) {
    if (_stopped) return;

    if (_running) {
      // Multiple requests during a sync collapse into 1 follow-up
      _pendingFollowUp = true;
      _pendingTrigger = trigger;
      return;
    }

    _run(trigger);
  }

  void requestSyncOnResume({
    Duration minInterval = const Duration(seconds: 30),
  }) {
    if (_stopped) return;
    final last = _lastSuccessfulSync;
    if (last != null && clock.now().difference(last) < minInterval) {
      return;
    }
    requestSync(SyncTrigger.appResume);
  }

  // Network back is just a hint from connectivity_plus
  void onNetworkBack() {
    if (_stopped) return;
    _networkDown = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    requestSync(SyncTrigger.networkBack);
  }

  void _scheduleTombstoneTimer(DateTime? eligibleAt) {
    _tombstoneTimer?.cancel();
    _tombstoneTimer = null;

    if (eligibleAt == null || _stopped) return;

    final now = clock.now().toUtc();
    final delay = eligibleAt.difference(now);
    final timerDelay = delay.isNegative ? Duration.zero : delay;

    _tombstoneTimer = Timer(timerDelay, () {
      if (!_stopped) {
        requestSync(SyncTrigger.undoWindowExpired);
      }
    });
  }

  // Internal loop

  Future<void> _run([SyncTrigger trigger = SyncTrigger.manual]) async {
    if (_stopped || _running) return;

    _running = true;
    _pendingFollowUp = false;
    _pendingTrigger = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _statusController.add(SyncStatus.syncing);

    final stopwatch = Stopwatch()..start();
    try {
      final result = await _syncEngine.syncOnce();
      stopwatch.stop();

      _logSyncRun(
        trigger: trigger,
        duration: stopwatch.elapsed,
        skippedTombstones: result.skippedTombstones,
        pushedCount: result.pushedCount,
        pulledCount: result.pulledCount,
        success: true,
      );

      _scheduleTombstoneTimer(result.nextTombstoneEligibleAt);
      _onSuccess();
    } on SyncFailure catch (e) {
      stopwatch.stop();
      _logSyncRun(
        trigger: trigger,
        duration: stopwatch.elapsed,
        skippedTombstones: 0,
        error: e,
        success: false,
      );
      _onFailure(e);
    } catch (e) {
      stopwatch.stop();
      _logSyncRun(
        trigger: trigger,
        duration: stopwatch.elapsed,
        skippedTombstones: 0,
        error: e,
        success: false,
      );
      _onFailure(UnknownSyncFailure(e));
    }
  }

  void _logSyncRun({
    required SyncTrigger trigger,
    required Duration duration,
    required int skippedTombstones,
    int pushedCount = 0,
    int pulledCount = 0,
    Object? error,
    bool success = true,
  }) {
    final entry = SyncRunLog(
      timestamp: clock.now().toUtc(),
      trigger: trigger,
      duration: duration,
      skippedTombstones: skippedTombstones,
      pushedCount: pushedCount,
      pulledCount: pulledCount,
      error: error,
      success: success,
    );
    _recentLogs.add(entry);
    if (_recentLogs.length > 100) {
      _recentLogs.removeAt(0);
    }
    developer.log(
      entry.toString(),
      name: 'cortex.sync',
      error: error,
    );
  }

  void _onSuccess() {
    _running = false;
    _consecutiveFailures = 0;
    _lastSuccessfulSync = clock.now();
    _statusController.add(SyncStatus.idle);

    if (_pendingFollowUp && !_stopped) {
      _pendingFollowUp = false;
      final nextTrigger = _pendingTrigger ?? SyncTrigger.manual;
      _pendingTrigger = null;
      _run(nextTrigger);
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
      _pendingTrigger = null;
      // Interface might be down, or server might be unreachable while Wi-Fi is fine.
      // Keep a slow 5-minute retry so it recovers even without a connectivity change.
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(minutes: 5), () {
        if (!_stopped) {
          _networkDown = false;
          _run(SyncTrigger.retry);
        }
      });
      return;
    }

    // Backoff: 5s, 10s, 20s, 40s... capped at 5 minutes
    final delay = _retryDelay();
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_stopped) {
        _run(SyncTrigger.retry);
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
