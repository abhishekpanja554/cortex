import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/widgets/empty_state.dart';
import 'package:cortex/core/widgets/page_header.dart';
import 'package:cortex/features/app_core/presentation/notifiers/app_notifier.dart';
import 'package:cortex/features/app_core/presentation/providers/providers.dart';
import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/widgets/note_sliver_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Focus the field when the user switches to this tab; drop focus when
    // they leave it so the keyboard doesn't follow them.
    ref.listen(appStateProvider.select((s) => s.currentTab), (prev, next) {
      if (next == AppNotifier.searchTab) {
        _focusNode.requestFocus();
      } else if (prev == AppNotifier.searchTab) {
        _focusNode.unfocus();
      }
    });

    final hasQuery = _query.trim().isNotEmpty;
    final asyncResults =
        hasQuery ? ref.watch(searchResultsProvider(_query.trim())) : null;
    final results = asyncResults?.asData?.value ?? const <NoteListItem>[];
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        const AppLargeTitleBar(title: AppStrings.search),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: CupertinoSearchTextField(
              controller: _controller,
              focusNode: _focusNode,
              placeholder: AppStrings.searchHint,
              onChanged: (value) => setState(() => _query = value),
              onSuffixTap: () {
                _controller.clear();
                setState(() => _query = '');
              },
              style: TextStyles.body,
              placeholderStyle: TextStyles.hint,
              backgroundColor: AppColors.surfaceMuted.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              padding: const EdgeInsetsDirectional.fromSTEB(8, 11, 8, 11),
              prefixInsets: const EdgeInsetsDirectional.fromSTEB(12, 0, 2, 2),
              suffixInsets: const EdgeInsetsDirectional.fromSTEB(0, 0, 10, 2),
            ),
          ),
        ),
        if (!hasQuery)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: CupertinoIcons.doc_text_search,
              title: AppStrings.searchEmptyTitle,
              message: AppStrings.searchEmptyBody,
            ),
          )
        else if (results.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: CupertinoIcons.search,
              title: AppStrings.searchNoResults,
              message: 'Nothing matches “${_query.trim()}”.',
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page + AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.xs,
              ),
              child: Text(
                results.length == 1 ? '1 result' : '${results.length} results',
                style: TextStyles.caption,
              ),
            ),
          ),
          NoteSliverList(notes: results, searchQuery: _query),
        ],
        SliverPadding(padding: EdgeInsets.only(bottom: bottomInset + AppSpacing.lg)),
      ],
    );
  }
}
