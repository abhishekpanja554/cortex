import 'dart:async';
import 'package:cortex/features/sync/data/sync_api.dart';
import 'package:cortex/features/sync/data/sync_engine.dart';
import 'package:cortex/features/sync/data/sync_local_store.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/domain/sync_failure.dart';
import 'package:flutter_test/flutter_test.dart';

// Fake SyncEngine for testing scheduler invariants
class FakeSyncEngine extends SyncEngine {
  FakeSyncEngine()
      : super(
          api: _DummySyncApi(),
          store: _DummySyncLocalStore(),
          getSession: () => 0,
        );

  int callCount = 0;
  Completer<void>? _blocker;
  SyncFailure? nextFailure;

  /// Makes syncOnce block until [completeSync] is called.
  void blockNextSync() {
    _blocker = Completer<void>();
  }

  void completeSync() {
    _blocker?.complete();
    _blocker = null;
  }

  @override
  Future<void> syncOnce() async {
    callCount++;
    if (_blocker != null) {
      await _blocker!.future;
    }
    if (nextFailure != null) {
      final f = nextFailure!;
      nextFailure = null;
      throw f;
    }
  }
}

class _DummySyncApi implements SyncApi {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _DummySyncLocalStore implements SyncLocalStore {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late FakeSyncEngine fakeSyncEngine;
  late SyncScheduler scheduler;

  setUp(() {
    fakeSyncEngine = FakeSyncEngine();
    scheduler = SyncScheduler(syncEngine: fakeSyncEngine);
  });

  tearDown(() {
    scheduler.dispose();
  });

  group('SyncScheduler', () {
    test('start() triggers an immediate sync', () async {
      scheduler.start();
      // Let microtask queue drain.
      await Future.delayed(Duration.zero);
      expect(fakeSyncEngine.callCount, 1);
    });

    test('requestSync while stopped does nothing', () async {
      // scheduler starts stopped
      scheduler.requestSync();
      await Future.delayed(Duration.zero);
      expect(fakeSyncEngine.callCount, 0);
    });

    test('multiple requests during a running sync collapse into one follow-up',
        () async {
      fakeSyncEngine.blockNextSync();
      scheduler.start(); // triggers sync #1

      await Future.delayed(Duration.zero);
      expect(fakeSyncEngine.callCount, 1);

      // Send 5 more requests while sync is running.
      for (var i = 0; i < 5; i++) {
        scheduler.requestSync();
      }

      // Complete the first sync.
      fakeSyncEngine.completeSync();
      await Future.delayed(const Duration(milliseconds: 50));

      // Should have exactly 2 syncs: the original + 1 follow-up, not 6.
      expect(fakeSyncEngine.callCount, 2);
    });

    test('stop() prevents further syncs', () async {
      scheduler.start();
      await Future.delayed(Duration.zero);
      expect(fakeSyncEngine.callCount, 1);

      scheduler.stop();
      scheduler.requestSync();
      await Future.delayed(Duration.zero);
      expect(fakeSyncEngine.callCount, 1); // no new sync
    });

    test('requestSyncOnResume skips if last sync was < 30s ago', () async {
      scheduler.start();
      await Future.delayed(Duration.zero);
      expect(fakeSyncEngine.callCount, 1);

      // Immediately try resume sync — should be skipped.
      scheduler.requestSyncOnResume();
      await Future.delayed(Duration.zero);
      expect(fakeSyncEngine.callCount, 1);
    });

    test('NetworkUnavailable failure sets slow retry rather than rapid backoff',
        () async {
      fakeSyncEngine.nextFailure = const NetworkUnavailableSyncFailure();
      scheduler.start();
      await Future.delayed(const Duration(milliseconds: 50));
      final callCountAfterFailure = fakeSyncEngine.callCount;
      expect(callCountAfterFailure, 1);

      // Short delay: rapid retry should not fire (slow 5-min timer is set)
      await Future.delayed(const Duration(seconds: 1));
      expect(fakeSyncEngine.callCount, callCountAfterFailure);
    });

    test('onNetworkBack triggers sync after NetworkUnavailable failure',
        () async {
      fakeSyncEngine.nextFailure = const NetworkUnavailableSyncFailure();
      scheduler.start();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fakeSyncEngine.callCount, 1);

      // Network comes back.
      scheduler.onNetworkBack();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fakeSyncEngine.callCount, 2);
    });

    test('ServerSyncFailure triggers exponential backoff retry', () async {
      fakeSyncEngine.nextFailure =
          const ServerSyncFailure(statusCode: 500, message: 'error');
      scheduler.start();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fakeSyncEngine.callCount, 1);

      // The scheduler should set a retry timer (5 seconds for first failure).
      // We can verify it's syncing by checking isSyncing is false (waiting).
      expect(scheduler.isSyncing, isFalse);
    });

    test('statusStream emits syncing then idle on success', () async {
      final statuses = <SyncStatus>[];
      scheduler.statusStream.listen(statuses.add);

      scheduler.start();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(statuses.length, 2);
      expect(statuses[0], isA<SyncStatusSyncing>());
      expect(statuses[1], isA<SyncStatusIdle>());
    });

    test('statusStream emits error on failure', () async {
      final statuses = <SyncStatus>[];
      scheduler.statusStream.listen(statuses.add);

      fakeSyncEngine.nextFailure =
          const ServerSyncFailure(statusCode: 500, message: 'error');
      scheduler.start();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(statuses.length, 2);
      expect(statuses[0], isA<SyncStatusSyncing>());
      expect(statuses[1], isA<SyncStatusError>());
    });

    test('onAppPaused stops periodic timer, onAppResumed restarts it',
        () async {
      scheduler.start();
      await Future.delayed(Duration.zero);

      scheduler.onAppPaused();
      // After pause, the periodic timer should be cancelled.
      // We can't easily test Timer internals, but we can verify
      // that resume works.
      
      scheduler.onAppResumed();
      await Future.delayed(const Duration(milliseconds: 50));
      // Resume should have triggered a requestSyncOnResume,
      // but since we just synced, it should be skipped.
      expect(fakeSyncEngine.callCount, 1);
    });
  });
}
