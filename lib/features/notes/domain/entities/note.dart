import 'package:freezed_annotation/freezed_annotation.dart';
part 'note.freezed.dart';

@freezed
abstract class Note with _$Note {
  const Note._();

  const factory Note({
    required String id,
    required String title,
    required String content,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? coverImage,
    @Default([]) List<Block> blocks,
    @Default([]) List<String> tags,
  }) = _Note;
  bool get isEmpty => title.isEmpty && content.isEmpty;
}

@freezed
sealed class Block with _$Block {
  const factory Block.text({
    required String id,
    required String data,
    @Default(0) int orderIndex,
  }) = TextBlock;

  const factory Block.image({
    required String id,
    required String data,
    @Default(0) int orderIndex,
  }) = ImageBlock;

  const factory Block.checkbox({
    required String id,
    required String data,
    @Default(false) bool isChecked,
    @Default(0) int orderIndex,
  }) = CheckboxBlock;
}
