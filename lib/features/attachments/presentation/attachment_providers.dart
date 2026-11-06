import 'dart:io';

import 'package:cortex/core/database/app_database_provider.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/attachments/data/attachment_api.dart';
import 'package:cortex/features/attachments/data/attachment_store.dart';
import 'package:cortex/features/attachments/data/attachment_uploader.dart';
import 'package:cortex/features/attachments/domain/attachment_ref.dart';
import 'package:cortex/features/sync/domain/sync_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final attachmentApiProvider = Provider<AttachmentApi>((ref) {
  return HttpAttachmentApi(ref.watch(apiDioProvider));
});

final attachmentStoreProvider = Provider<AttachmentStore>((ref) {
  return AttachmentStore(
    ref.watch(appDatabaseProvider),
    ref.watch(documentsDirectoryProvider),
  );
});

final attachmentUploaderProvider = Provider<AttachmentUploader>((ref) {
  return AttachmentUploader(
    api: ref.watch(attachmentApiProvider),
    store: ref.watch(attachmentStoreProvider),
  );
});

/// The local file for an image a note refers to, downloaded first when it
/// isn't on this device (fresh install, picked on another device, or after
/// logout). Null when it can't be had right now: offline, or never uploaded.
///
/// One download per path at a time, however many widgets show it; disposed
/// when nothing shows it, so reopening the note retries.
final attachmentFileProvider =
    FutureProvider.autoDispose.family<File?, String>((ref, path) async {
  final attachment = AttachmentRef.parse(path);
  if (attachment == null) return null;

  final store = ref.watch(attachmentStoreProvider);
  final file = store.fileFor(attachment.relativePath);
  if (await file.exists()) return file;

  final auth = ref.read(authRepositoryProvider);
  final session = auth.currentSession;
  final List<int>? bytes;
  try {
    bytes = await ref.read(attachmentApiProvider).download(attachment.id);
  } on SyncFailure {
    return null;
  }

  // Logged out while downloading: local data has been wiped, so don't write
  // the previous account's image into the next session.
  if (bytes == null || auth.currentSession != session) return null;
  return store.saveDownloaded(attachment.relativePath, bytes);
});
