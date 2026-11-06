import 'dart:io';
import 'dart:typed_data';

import 'package:cortex/features/attachments/data/attachment_api.dart';
import 'package:cortex/features/attachments/data/attachment_store.dart';
import 'package:cortex/features/attachments/domain/attachment_ref.dart';
import 'package:cortex/features/sync/domain/sync_failure.dart';

/// Uploads images picked on this device, so other devices (and this one after
/// a reinstall) can download them. Runs at the start of every sync round.
class AttachmentUploader {
  final AttachmentApi _api;
  final AttachmentStore _store;

  AttachmentUploader({
    required AttachmentApi api,
    required AttachmentStore store,
  }) : _api = api,
       _store = store;

  /// Returns how many images were uploaded. Network loss and logout propagate
  /// (the round can't continue); a server error on one image leaves it queued
  /// for the next round without holding back the notes.
  Future<int> uploadPending({required void Function() checkSession}) async {
    final paths = await _store.pendingUploads();
    var uploaded = 0;

    for (final path in paths) {
      checkSession();
      final ref = AttachmentRef.parse(path);
      final file = _store.fileFor(path);
      if (ref == null || !await file.exists()) {
        await _store.removeFromQueue(path);
        continue;
      }

      final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } on FileSystemException {
        // Deleted between the check and the read (e.g. logout wiped it).
        continue;
      }
      checkSession();

      try {
        await _api.upload(ref.id, bytes);
      } on ServerSyncFailure catch (e) {
        // Retrying can't fix these: too large, not an image, id owned by
        // someone else.
        if (const {409, 413, 415}.contains(e.statusCode)) {
          await _store.removeFromQueue(path);
        }
        continue;
      }

      checkSession();
      await _store.removeFromQueue(path);
      uploaded++;
    }
    return uploaded;
  }
}
