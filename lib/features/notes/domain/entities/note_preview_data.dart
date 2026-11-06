import 'dart:convert';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/note_body_codec.dart';

class PreviewTodoItem {
  final String text;
  final bool isChecked;

  const PreviewTodoItem({
    required this.text,
    required this.isChecked,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'checked': isChecked,
  };

  factory PreviewTodoItem.fromJson(Map<String, dynamic> json) => PreviewTodoItem(
    text: json['text'] as String? ?? '',
    isChecked: json['checked'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreviewTodoItem &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          isChecked == other.isChecked;

  @override
  int get hashCode => Object.hash(text, isChecked);
}

class NotePreviewData {
  final String previewText;
  final String? firstImagePath;
  final String previewTodos;
  final List<PreviewTodoItem> topTodos;

  const NotePreviewData({
    required this.previewText,
    this.firstImagePath,
    required this.previewTodos,
    this.topTodos = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotePreviewData &&
          runtimeType == other.runtimeType &&
          previewText == other.previewText &&
          firstImagePath == other.firstImagePath &&
          previewTodos == other.previewTodos;

  @override
  int get hashCode => Object.hash(previewText, firstImagePath, previewTodos);
}

/// Computes the preview fields from a serialized note body.
///
/// Returns:
/// - [NotePreviewData.previewText]: plain text cut to 160 characters.
/// - [NotePreviewData.firstImagePath]: path to the first image block, if any.
/// - [NotePreviewData.previewTodos]: JSON string containing up to 3 checkbox items.
/// - [NotePreviewData.topTodos]: parsed list of the top checkbox items.
NotePreviewData computePreview(String body) {
  if (body.isEmpty) {
    return const NotePreviewData(
      previewText: '',
      firstImagePath: null,
      previewTodos: '[]',
      topTodos: [],
    );
  }

  const codec = NoteBodyCodec();
  final blocks = codec.parse(body);

  // Extract plain text and cut to ~160 characters
  final rawPlainText = blocks
      .whereType<TextBlock>()
      .map((b) => b.data)
      .join('\n')
      .trim();
  final previewText =
      rawPlainText.length > 160 ? rawPlainText.substring(0, 160) : rawPlainText;

  // Extract first image path
  final firstImagePath = blocks.whereType<ImageBlock>().firstOrNull?.data;

  // Extract up to 3 todos and serialize as JSON
  final topTodos = blocks
      .whereType<CheckboxBlock>()
      .take(3)
      .map((b) => PreviewTodoItem(text: b.data, isChecked: b.isChecked))
      .toList();
  final previewTodos = jsonEncode(topTodos.map((t) => t.toJson()).toList());

  return NotePreviewData(
    previewText: previewText,
    firstImagePath: firstImagePath,
    previewTodos: previewTodos,
    topTodos: topTodos,
  );
}
