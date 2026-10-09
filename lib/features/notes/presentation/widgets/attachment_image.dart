import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cortex/core/providers/core_providers.dart';

class AttachmentImage extends ConsumerWidget {
  final String path;
  final BoxFit fit;

  const AttachmentImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    File file;
    if (path.startsWith('attachments/')) {
      final dir = ref.watch(documentsDirectoryProvider);
      file = File('${dir.path}/$path');
    } else {
      file = File(path);
    }
    return Image.file(
      file, 
      fit: fit,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
