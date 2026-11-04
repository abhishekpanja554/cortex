/// Note bodies reference images as `attachments/<uuid>.<ext>`, relative to the
/// app's Documents folder. The uuid doubles as the server's attachment id.
const _uuid =
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

final _inBody = RegExp('attachments/$_uuid\\.[A-Za-z0-9]+');

// Also accepts the older absolute paths that end in the same relative path.
final _wholePath = RegExp('(?:^|/)(attachments/($_uuid)\\.[A-Za-z0-9]+)\$');

class AttachmentRef {
  final String id;
  final String relativePath;

  const AttachmentRef({required this.id, required this.relativePath});

  /// Null for paths that aren't synced attachments (e.g. the perf sample image).
  static AttachmentRef? parse(String path) {
    final match = _wholePath.firstMatch(path);
    if (match == null) return null;
    return AttachmentRef(id: match.group(2)!, relativePath: match.group(1)!);
  }

  /// Every attachment path a markdown note body refers to.
  static Iterable<String> pathsIn(String body) =>
      _inBody.allMatches(body).map((m) => m.group(0)!);
}
