import 'dart:convert';
import 'package:cortex/features/notes/domain/entities/note_preview_data.dart';

class NoteListItem {
  final String id;
  final String title;
  final String previewText;
  final String? firstImagePath;
  final String previewTodos;
  final List<PreviewTodoItem>? _topTodos;
  late final List<PreviewTodoItem> topTodos =
      _topTodos ?? _parseTodos(previewTodos);
  final String rawCreatedAt;
  final String rawUpdatedAt;
  final DateTime? _createdAt;
  final DateTime? _updatedAt;
  late final DateTime createdAt = _createdAt ?? _parseDate(rawCreatedAt);
  late final DateTime updatedAt = _updatedAt ?? _parseDate(rawUpdatedAt);
  final String? conflictOf;
  final String? conflictField;

  NoteListItem({
    required this.id,
    required this.title,
    required this.previewText,
    this.firstImagePath,
    required this.previewTodos,
    List<PreviewTodoItem>? topTodos,
    String? rawCreatedAt,
    String? rawUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.conflictOf,
    this.conflictField,
  })  : _topTodos = topTodos,
        _createdAt = createdAt,
        _updatedAt = updatedAt,
        rawCreatedAt = rawCreatedAt ?? (createdAt?.toIso8601String() ?? ''),
        rawUpdatedAt = rawUpdatedAt ?? (updatedAt?.toIso8601String() ?? '');

  static DateTime _parseDate(String raw) {
    if (raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    final asInt = int.tryParse(raw);
    if (asInt != null) {
      return asInt > 10000000000
          ? DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(asInt * 1000, isUtc: true);
    }
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  static List<PreviewTodoItem> _parseTodos(String jsonStr) {
    if (jsonStr.isEmpty || jsonStr == '[]') return const [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => PreviewTodoItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteListItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          previewText == other.previewText &&
          firstImagePath == other.firstImagePath &&
          previewTodos == other.previewTodos &&
          rawCreatedAt == other.rawCreatedAt &&
          rawUpdatedAt == other.rawUpdatedAt &&
          conflictOf == other.conflictOf &&
          conflictField == other.conflictField;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        previewText,
        firstImagePath,
        previewTodos,
        rawCreatedAt,
        rawUpdatedAt,
        conflictOf,
        conflictField,
      );
}
