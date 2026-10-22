import 'package:cortex/core/database/app_database_provider.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/sync/data/sync_api.dart';
import 'package:cortex/features/sync/data/sync_engine.dart';
import 'package:cortex/features/sync/data/sync_local_store.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final syncApiProvider = Provider<SyncApi>((ref) {
  return HttpSyncApi(ref.watch(apiDioProvider));
});

final syncLocalStoreProvider = Provider<SyncLocalStore>((ref) {
  return SyncLocalStore(ref.watch(appDatabaseProvider));
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    api: ref.watch(syncApiProvider),
    store: ref.watch(syncLocalStoreProvider),
    getSession: () => ref.read(authRepositoryProvider).currentSession,
  );
});

final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(
    syncEngine: ref.watch(syncEngineProvider),
  );
  ref.onDispose(() => scheduler.dispose());
  return scheduler;
});

/// Latest sync status for the UI (header chip). Emits nothing until the
/// scheduler reports, so treat "no value yet" as idle.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.watch(syncSchedulerProvider).statusStream;
});
