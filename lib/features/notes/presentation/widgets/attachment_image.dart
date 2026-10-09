import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AttachmentImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const AttachmentImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
  });

  Future<File> _resolvePath() async {
    if (path.startsWith('attachments/')) {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$path');
    }
    return File(path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _resolvePath(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.file(snapshot.data!, fit: fit);
        }
        return const SizedBox.shrink();
      },
    );
  }
}
