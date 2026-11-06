import 'dart:io';

import 'package:cortex/core/database/app_database.dart';
import 'package:drift/drift.dart';

/// Attachment files in the app's Documents folder, and the queue of ones
/// picked on this device that still need uploading.
class AttachmentStore {
  final AppDatabase _db;
  final Directory _docsDir;

  AttachmentStore(this._db, this._docsDir);

  File fileFor(String relativePath) => File('${_docsDir.path}/$relativePath');

  Future<void> queueUpload(String relativePath) {
    return _db.into(_db.pendingUploads).insert(
          PendingUploadsCompanion.insert(path: relativePath),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<List<String>> pendingUploads() async {
    final rows = await (_db.select(_db.pendingUploads)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    return [for (final row in rows) row.path];
  }

  Future<void> removeFromQueue(String relativePath) {
    return (_db.delete(_db.pendingUploads)
          ..where((t) => t.path.equals(relativePath)))
        .go();
  }

  Future<File> saveDownloaded(String relativePath, List<int> bytes) async {
    final file = fileFor(relativePath);
    await file.parent.create(recursive: true);
    // Write then rename, so a crash mid-write never leaves a truncated image
    // that looks like a finished download.
    final temp = File('${file.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    return temp.rename(file.path);
  }
}
