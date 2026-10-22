import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/theme/liquid_glass.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/domain/sync_failure.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Glass capsule showing whether notes are synced. Tap to sync now.
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value ?? SyncStatus.idle;

    final (IconData icon, String label, Color color) = switch (status) {
      SyncStatusSyncing() => (CupertinoIcons.arrow_2_circlepath, 'Syncing', AppColors.primary),
      SyncStatusError(failure: NetworkUnavailableSyncFailure()) =>
        (CupertinoIcons.wifi_slash, 'Offline', AppColors.textSecondary),
      SyncStatusError() => (CupertinoIcons.exclamationmark_circle, 'Sync failed', AppColors.red),
      SyncStatusIdle() => (CupertinoIcons.checkmark_alt, 'Synced', AppColors.success),
    };

    return Semantics(
      button: true,
      label: '$label. Tap to sync now',
      excludeSemantics: true,
      child: GlassPill(
        onTap: status is SyncStatusSyncing
            ? null
            : () => ref.read(syncSchedulerProvider).requestSync(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status is SyncStatusSyncing)
              const CupertinoActivityIndicator(radius: 7)
            else
              Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.08,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
