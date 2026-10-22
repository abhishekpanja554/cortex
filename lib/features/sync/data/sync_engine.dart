import 'package:clock/clock.dart';
import 'package:cortex/features/sync/data/sync_api.dart';
import 'package:cortex/features/sync/data/sync_local_store.dart';
import 'package:cortex/features/sync/domain/sync_failure.dart';

class SyncResult {
  final DateTime? nextTombstoneEligibleAt;
  final int skippedTombstones;
  final int pushedCount;
  final int pulledCount;

  const SyncResult({
    this.nextTombstoneEligibleAt,
    this.skippedTombstones = 0,
    this.pushedCount = 0,
    this.pulledCount = 0,
  });

  DateTime? get earliestEligibleAt => nextTombstoneEligibleAt;

  static const empty = SyncResult();
}

class SyncEngine {
  final SyncApi _api;
  final SyncLocalStore _store;
  final int Function() _getSession;
  final Duration undoGracePeriod;

  SyncEngine({
    required SyncApi api,
    required SyncLocalStore store,
    required int Function() getSession,
    this.undoGracePeriod = const Duration(seconds: 6),
  }) : _api = api,
       _store = store,
       _getSession = getSession;

  Future<SyncResult> syncOnce() async {
    // Snapshot current session so we can bail out if the user logs out mid-sync
    final session = _getSession();

    void checkSession() {
      if (_getSession() != session) {
        throw const SessionExpiredSyncFailure();
      }
    }

    // 1. Gather dirty notes and push changed fields
    final dirtyNotes = await _store.getDirtyNotes();
    checkSession();

    DateTime? earliestEligibleAt;
    int skippedTombstones = 0;
    int pushedCount = 0;
    int pulledCount = 0;

    if (dirtyNotes.isNotEmpty) {
      final pushList = <Map<String, dynamic>>[];
      final sentContentMap = <String, ({String? title, String? body})>{};
      final now = clock.now().toUtc();

      for (final note in dirtyNotes) {
        final isTombstone =
            note.deletedAt != null && (note.titleDirty || note.bodyDirty);

        if (isTombstone) {
          final deletedAt = note.deletedAt;
          if (deletedAt != null) {
            final eligibleAt = deletedAt.toUtc().add(undoGracePeriod);
            if (now.isBefore(eligibleAt)) {
              skippedTombstones++;
              if (earliestEligibleAt == null ||
                  eligibleAt.isBefore(earliestEligibleAt)) {
                earliestEligibleAt = eligibleAt;
              }
              // Skip pushing tombstone if it is still within the undo window
              continue;
            }
          }
          pushList.add({'id': note.id, 'deleted': true});
          sentContentMap[note.id] = (title: null, body: null);
        } else {
          final map = <String, dynamic>{'id': note.id};
          String? sentTitle;
          String? sentBody;

          if (note.titleDirty) {
            map['title'] = note.title;
            map['titleBaseUpdatedAt'] = note.serverTitleUpdatedAt;
            sentTitle = note.title;
          }
          if (note.bodyDirty) {
            map['body'] = note.body;
            map['bodyBaseUpdatedAt'] = note.serverBodyUpdatedAt;
            sentBody = note.body;
          }

          pushList.add(map);
          sentContentMap[note.id] = (title: sentTitle, body: sentBody);
        }
      }

      if (pushList.isNotEmpty) {
        final pushResults = await _api.push(pushList);
        checkSession();
        pushedCount = pushResults.length;

        // 2. Apply server push responses (update stamps, clear clean flags)
        for (final res in pushResults) {
          checkSession();
          final sent = sentContentMap[res.id];
          await _store.applyPushResult(
            res,
            sentTitle: sent?.title,
            sentBody: sent?.body,
          );
        }
      }
    }

    // 3. Pull latest changes
    checkSession();
    final cursor = await _store.getCursor();
    checkSession();

    final pullResponse = await _api.pull(since: cursor);
    checkSession();
    pulledCount = pullResponse.notes.length;

    for (final pulledNote in pullResponse.notes) {
      checkSession();
      await _store.applyPulledNote(pulledNote);
    }

    // Persist latest pagination cursor
    checkSession();
    if (pullResponse.nextSince != null) {
      await _store.saveCursor(pullResponse.nextSince!);
    }

    return SyncResult(
      nextTombstoneEligibleAt: earliestEligibleAt,
      skippedTombstones: skippedTombstones,
      pushedCount: pushedCount,
      pulledCount: pulledCount,
    );
  }
}
