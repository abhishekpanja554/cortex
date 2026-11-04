import 'dart:io';

import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/core/theme/app_shapes.dart';
import 'package:cortex/features/attachments/presentation/attachment_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves an image path stored in a note body to a file on this device.
///
/// New notes store paths relative to the app's Documents folder
/// (`attachments/<uuid>.jpg`). Older absolute paths are re-anchored to the
/// current Documents folder, because iOS changes the app container path
/// between installs.
File resolveAttachmentFile(String path, Directory documentsDir) {
  if (path.startsWith('attachments/')) {
    return File('${documentsDir.path}/$path');
  }
  final file = File(path);
  if (file.existsSync()) return file;

  const marker = '/Documents/';
  final idx = path.indexOf(marker);
  if (idx != -1) {
    return File('${documentsDir.path}/${path.substring(idx + marker.length)}');
  }
  return file;
}

/// Shows a note's image attachment.
///
/// When the file isn't on this device (fresh install, picked on another
/// device, after logging out and back in) it's downloaded from the server.
/// Until then — or if that fails, e.g. offline — it shows a clear placeholder
/// instead of an invisible gap, or nothing at all when [hideWhenMissing] is
/// set (used for list-card covers).
class AttachmentImage extends ConsumerWidget {
  final String path;
  final BoxFit fit;
  final double? height;
  final double borderRadius;
  final bool hideWhenMissing;

  const AttachmentImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.height,
    this.borderRadius = AppRadius.md,
    this.hideWhenMissing = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = resolveAttachmentFile(path, ref.watch(documentsDirectoryProvider));
    if (file.existsSync()) return _buildImage(context, file);

    // Not on this device: fetch it from the server.
    final download = ref.watch(attachmentFileProvider(path));
    return switch (download) {
      AsyncData(value: final File downloaded) => _buildImage(context, downloaded),
      _ when hideWhenMissing => const SizedBox.shrink(),
      AsyncLoading() => const _MissingImage(loading: true),
      _ => const _MissingImage(),
    };
  }

  Widget _buildImage(BuildContext context, File file) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipPath(
      clipper: ShapeBorderClipper(shape: AppShapes.continuous(borderRadius)),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Image.file(
          file,
          fit: fit,
          // Decode list covers at display size instead of full camera size.
          cacheHeight: height == null ? null : (height! * dpr).round(),
          errorBuilder: (context, error, stackTrace) => hideWhenMissing
              ? const SizedBox.shrink()
              : const _MissingImage(),
        ),
      ),
    );
  }
}

class _MissingImage extends StatelessWidget {
  final bool loading;

  const _MissingImage({this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Extra right padding leaves room for the editor's remove (×) button.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        48,
        AppSpacing.xl,
      ),
      decoration: ShapeDecoration(
        color: AppColors.surfaceMuted,
        shape: AppShapes.continuous(AppRadius.lg),
      ),
      child: Row(
        children: [
          loading
              ? const CupertinoActivityIndicator()
              : const Icon(CupertinoIcons.photo, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              loading
                  ? 'Downloading image…'
                  : 'This image isn’t available right now.',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
