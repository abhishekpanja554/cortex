import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/core/database/app_database_provider.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/attachments/data/attachment_api.dart';
import 'package:cortex/features/attachments/data/attachment_store.dart';
import 'package:cortex/features/attachments/data/attachment_uploader.dart';
import 'package:cortex/features/attachments/domain/attachment_ref.dart';
import 'package:cortex/features/attachments/presentation/attachment_providers.dart';
import 'package:cortex/features/auth/data/auth_repository.dart';
import 'package:cortex/features/sync/data/sync_api.dart';
import 'package:cortex/features/sync/data/sync_engine.dart';
import 'package:cortex/features/sync/data/sync_local_store.dart';
import 'package:cortex/features/sync/domain/sync_failure.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _idA = '11111111-1111-4111-8111-111111111111';
const _idB = '22222222-2222-4222-8222-222222222222';
const _pathA = 'attachments/$_idA.jpg';
const _pathB = 'attachments/$_idB.jpg';

class FakeAttachmentApi implements AttachmentApi {
  final uploads = <String, Uint8List>{};
  final calls = <String>[];
  final failUploads = <String, SyncFailure>{};
  final server = <String, Uint8List>{};
  Completer<void>? downloadGate;

  @override
  Future<void> upload(String id, Uint8List bytes) async {
    calls.add('upload $id');
    final failure = failUploads[id];
    if (failure != null) throw failure;
    uploads[id] = bytes;
  }

  @override
  Future<Uint8List?> download(String id) async {
    calls.add('download $id');
    await downloadGate?.future;
    return server[id];
  }
}

class _RecordingSyncApi implements SyncApi {
  final List<String> calls;
  _RecordingSyncApi(this.calls);

  @override
  Future<List<PushNoteResult>> push(List<Map<String, dynamic>> notes) async {
    calls.add('push');
    return const [];
  }

  @override
  Future<PullResponse> pull({String? since}) async {
    calls.add('pull');
    return const PullResponse(notes: []);
  }
}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late AppDatabase db;
  late Directory docs;
  late AttachmentStore store;
  late FakeAttachmentApi api;
  late AttachmentUploader uploader;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = await Directory.systemTemp.createTemp('attachments_test');
    store = AttachmentStore(db, docs);
    api = FakeAttachmentApi();
    uploader = AttachmentUploader(api: api, store: store);
  });

  tearDown(() async {
    await db.close();
    await docs.delete(recursive: true);
  });

  Future<void> writeLocal(String path, List<int> bytes) async {
    final file = store.fileFor(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  group('AttachmentRef', () {
    test('parses relative and legacy absolute paths', () {
      final rel = AttachmentRef.parse(_pathA)!;
      expect(rel.id, _idA);
      expect(rel.relativePath, _pathA);

      final abs = AttachmentRef.parse('/var/mobile/Containers/X/Documents/$_pathA')!;
      expect(abs.id, _idA);
      expect(abs.relativePath, _pathA);
    });

    test('ignores paths that are not synced attachments', () {
      expect(AttachmentRef.parse('attachments/perf_sample.jpg'), isNull);
      expect(AttachmentRef.parse('/tmp/image_picker_123.jpg'), isNull);
      expect(AttachmentRef.parse('xattachments/$_idA.jpg'), isNull);
    });

    test('finds every attachment path in a markdown body', () {
      const body = 'Intro\n\n![](<$_pathA>)\n\n- [ ] todo\n\n![]($_pathB)\n\n![](<attachments/perf_sample.jpg>)';
      expect(AttachmentRef.pathsIn(body).toList(), [_pathA, _pathB]);
    });
  });

  group('AttachmentUploader', () {
    test('uploads a queued image and removes it from the queue', () async {
      await writeLocal(_pathA, [0xFF, 0xD8, 0xFF, 1, 2, 3]);
      await store.queueUpload(_pathA);

      final count = await uploader.uploadPending(checkSession: () {});

      expect(count, 1);
      expect(api.uploads[_idA], [0xFF, 0xD8, 0xFF, 1, 2, 3]);
      expect(await store.pendingUploads(), isEmpty);
    });

    test('queueing the same path twice uploads it once', () async {
      await writeLocal(_pathA, [1]);
      await store.queueUpload(_pathA);
      await store.queueUpload(_pathA);

      await uploader.uploadPending(checkSession: () {});

      expect(api.calls, ['upload $_idA']);
    });

    test('drops a queued path whose file no longer exists', () async {
      await store.queueUpload(_pathA);

      await uploader.uploadPending(checkSession: () {});

      expect(api.calls, isEmpty);
      expect(await store.pendingUploads(), isEmpty);
    });

    test('drops permanently rejected images, keeps server errors queued, and carries on', () async {
      const idC = '33333333-3333-4333-8333-333333333333';
      await writeLocal(_pathA, [1]);
      await writeLocal(_pathB, [2]);
      await writeLocal('attachments/$idC.jpg', [3]);
      await store.queueUpload(_pathA);
      await store.queueUpload(_pathB);
      await store.queueUpload('attachments/$idC.jpg');
      api.failUploads[_idA] = const ServerSyncFailure(statusCode: 413);
      api.failUploads[_idB] = const ServerSyncFailure(statusCode: 503);

      final count = await uploader.uploadPending(checkSession: () {});

      expect(count, 1);
      expect(api.uploads.keys, [idC]);
      expect(await store.pendingUploads(), [_pathB]);
    });

    test('network loss propagates and leaves the image queued', () async {
      await writeLocal(_pathA, [1]);
      await store.queueUpload(_pathA);
      api.failUploads[_idA] = const NetworkUnavailableSyncFailure();

      await expectLater(
        uploader.uploadPending(checkSession: () {}),
        throwsA(isA<NetworkUnavailableSyncFailure>()),
      );
      expect(await store.pendingUploads(), [_pathA]);
    });

    test('stops before uploading when the session has changed', () async {
      await writeLocal(_pathA, [1]);
      await store.queueUpload(_pathA);

      await expectLater(
        uploader.uploadPending(
          checkSession: () => throw const SessionExpiredSyncFailure(),
        ),
        throwsA(isA<SessionExpiredSyncFailure>()),
      );
      expect(api.calls, isEmpty);
    });
  });

  test('SyncEngine uploads images before pushing notes', () async {
    final calls = <String>[];
    final recordingApi = FakeAttachmentApi();
    await writeLocal(_pathA, [1]);
    await store.queueUpload(_pathA);
    final engine = SyncEngine(
      api: _RecordingSyncApi(calls),
      store: SyncLocalStore(db),
      getSession: () => 1,
      attachmentUploader: AttachmentUploader(
        api: _ForwardingApi(recordingApi, calls),
        store: store,
      ),
    );
    final now = DateTime.now().toUtc();
    await db.into(db.notes).insert(NotesCompanion.insert(
      body: const Value('![](<$_pathA>)'),
      bodyDirty: const Value(true),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    await engine.syncOnce();

    expect(calls, ['upload $_idA', 'push', 'pull']);
  });

  group('attachmentFileProvider', () {
    late _MockAuthRepository auth;
    late int session;
    late ProviderContainer container;

    setUp(() {
      auth = _MockAuthRepository();
      session = 1;
      when(() => auth.currentSession).thenAnswer((_) => session);
      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        documentsDirectoryProvider.overrideWithValue(docs),
        attachmentApiProvider.overrideWithValue(api),
        authRepositoryProvider.overrideWithValue(auth),
      ]);
    });

    tearDown(() => container.dispose());

    Future<File?> read(String path) {
      final sub = container.listen(attachmentFileProvider(path), (_, _) {});
      addTearDown(sub.close);
      return container.read(attachmentFileProvider(path).future);
    }

    test('returns the local file without downloading', () async {
      await writeLocal(_pathA, [1]);

      final file = await read(_pathA);

      expect(await file!.readAsBytes(), [1]);
      expect(api.calls, isEmpty);
    });

    test('downloads a missing image and saves it where the note expects it', () async {
      api.server[_idA] = Uint8List.fromList([9, 8, 7]);

      final file = await read(_pathA);

      expect(file!.path, store.fileFor(_pathA).path);
      expect(await file.readAsBytes(), [9, 8, 7]);
      expect(File('${file.path}.part').existsSync(), isFalse);
    });

    test('a legacy absolute path downloads into the relative location', () async {
      api.server[_idA] = Uint8List.fromList([5]);

      final file = await read('/old/container/Documents/$_pathA');

      expect(file!.path, store.fileFor(_pathA).path);
    });

    test('returns null when the server has no copy', () async {
      expect(await read(_pathA), isNull);
      expect(api.calls, ['download $_idA']);
    });

    test('does not write an image that arrives after logout', () async {
      api.server[_idA] = Uint8List.fromList([1]);
      api.downloadGate = Completer<void>();

      final pending = read(_pathA);
      await Future<void>.delayed(Duration.zero);
      session = 2;
      api.downloadGate!.complete();

      expect(await pending, isNull);
      expect(store.fileFor(_pathA).existsSync(), isFalse);
    });

    test('ignores paths that are not synced attachments', () async {
      expect(await read('attachments/perf_sample.jpg'), isNull);
      expect(api.calls, isEmpty);
    });
  });
}

class _ForwardingApi implements AttachmentApi {
  final FakeAttachmentApi _inner;
  final List<String> _calls;
  _ForwardingApi(this._inner, this._calls);

  @override
  Future<void> upload(String id, Uint8List bytes) {
    _calls.add('upload $id');
    return _inner.upload(id, bytes);
  }

  @override
  Future<Uint8List?> download(String id) => _inner.download(id);
}
