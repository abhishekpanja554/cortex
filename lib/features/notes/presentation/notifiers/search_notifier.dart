import 'dart:async';

import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchState {
  final String query;
  final List<NoteListItem> results;
  final bool isLoading;
  final int searchId;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.searchId = 0,
  });

  SearchState copyWith({
    String? query,
    List<NoteListItem>? results,
    bool? isLoading,
    int? searchId,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      searchId: searchId ?? this.searchId,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounceTimer;
  int _latestSearchId = 0;

  @override
  SearchState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const SearchState();
  }

  void onQueryChanged(String query) {
    _debounceTimer?.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _latestSearchId++;
      state = SearchState(
        query: query,
        results: const [],
        isLoading: false,
        searchId: _latestSearchId,
      );
      return;
    }

    final searchId = ++_latestSearchId;
    state = state.copyWith(query: query, isLoading: true);

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final repo = ref.read(noteRepositoryProvider);
        final results = await repo.searchNotes(trimmed);

        // Latest-wins pattern: drop results whose number isn't the latest
        if (searchId < _latestSearchId) {
          return;
        }

        state = state.copyWith(
          results: results,
          isLoading: false,
          searchId: searchId,
        );
      } catch (_) {
        // Suppress search failure so finally resets isLoading
      } finally {
        if (searchId == _latestSearchId && state.isLoading) {
          state = state.copyWith(isLoading: false);
        }
      }
    });
  }

  void clear() {
    _debounceTimer?.cancel();
    _latestSearchId++;
    state = const SearchState();
  }
}
