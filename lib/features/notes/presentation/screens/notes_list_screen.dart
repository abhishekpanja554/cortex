import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/navigation/note_routes.dart';
import 'package:cortex/core/widgets/empty_state.dart';
import 'package:cortex/core/widgets/page_header.dart';
import 'package:cortex/features/notes/domain/note_search.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/widgets/note_sliver_list.dart';
import 'package:cortex/features/notes/presentation/widgets/quick_action_grid.dart';
import 'package:cortex/features/notes/presentation/widgets/sync_status_chip.dart';
import 'package:cortex/features/sync/presentation/sync_orchestrator.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = searchNotes(ref.watch(noteNotifierProvider).notes, '');
    final count = notes.length;
    // With extendBody, the Scaffold reports the floating tab bar's height here.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      slivers: [
        const AppLargeTitleBar(
          title: AppStrings.notes,
          trailing: SyncStatusChip(),
        ),
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            final orchestrator = SyncOrchestrator.of(context);
            if (orchestrator != null) {
              await orchestrator.onPullToRefresh();
            } else {
              ref.read(syncSchedulerProvider).requestSync();
            }
          },
        ),
        const SliverToBoxAdapter(child: SectionLabel(AppStrings.create)),
        SliverToBoxAdapter(
          child: QuickActionGrid(
            onSelected: (template) => NoteRoutes.create(context, template),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionLabel(
            AppStrings.recentNotes,
            trailing: count == 0
                ? null
                : Text(count == 1 ? '1 note' : '$count notes', style: TextStyles.caption),
          ),
        ),
        if (notes.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: CupertinoIcons.doc_text,
              title: AppStrings.noNotesTitle,
              message: AppStrings.noNotesBody,
            ),
          )
        else
          NoteSliverList(notes: notes),
        SliverPadding(
          padding: EdgeInsets.only(bottom: bottomInset + AppSpacing.lg),
        ),
      ],
    );
  }
}
