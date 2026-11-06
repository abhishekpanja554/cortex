import 'package:freezed_annotation/freezed_annotation.dart';

part 'note_entity.freezed.dart';

@freezed
abstract class NoteEntity with _$NoteEntity {
  const NoteEntity._();

  const factory NoteEntity({
    required String id,
    required String title,
    required String body,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? conflictOf,
    String? conflictField,
  }) = _NoteEntity;

  bool get isEmpty => title.isEmpty && body.isEmpty;
}

@freezed
sealed class Block with _$Block {
  const factory Block.text({required String id, required String data}) =
      TextBlock;

  const factory Block.image({required String id, required String data}) =
      ImageBlock;

  const factory Block.checkbox({
    required String id,
    required String data,
    @Default(false) bool isChecked,
  }) = CheckboxBlock;
}
