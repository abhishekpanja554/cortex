import 'package:cortex/features/notes/domain/entities/note.dart' as domain;
import 'package:isar_community/isar.dart';

part 'note_isar_model.g.dart';

@collection
class IsarNote {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? uuid;

  String? title;

  String? content;

  DateTime? createdAt;

  DateTime? updatedAt;

  String? coverImage;

  List<String>? tags;

  List<IsarBlock>? blocks;
}

@embedded
class IsarBlock {
  String? id;

  @enumerated
  IsarBlockType type = IsarBlockType.text;

  String? data;

  bool? isChecked;

  int? orderIndex;
}

enum IsarBlockType { text, image, todo }

extension IsarNoteMapper on IsarNote {
  domain.Note toDomain() {
    return domain.Note(
      id: uuid ?? id.toString(),
      title: title ?? '',
      content: content ?? '',
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt,
      coverImage: coverImage,
      tags: tags ?? [],
      blocks: blocks?.map((b) => b.toDomain()).toList() ?? [],
    );
  }
}

extension DomainNoteMapper on domain.Note {
  IsarNote toIsar() {
    return IsarNote()
      ..uuid = id
      ..title = title
      ..content = content
      ..createdAt = createdAt
      ..updatedAt = updatedAt
      ..coverImage = coverImage
      ..tags = tags
      ..blocks = blocks.map((b) => b.toIsar()).toList();
  }
}

extension IsarBlockMapper on IsarBlock {
  domain.Block toDomain() {
    switch (type) {
      case IsarBlockType.text:
        return domain.Block.text(
          id: id ?? '',
          data: data ?? '',
          orderIndex: orderIndex ?? 0,
        );
      case IsarBlockType.image:
        return domain.Block.image(
          id: id ?? '',
          data: data ?? '',
          orderIndex: orderIndex ?? 0,
        );
      case IsarBlockType.todo:
        return domain.Block.checkbox(
          id: id ?? '',
          data: data ?? '',
          isChecked: isChecked ?? false,
          orderIndex: orderIndex ?? 0,
        );
    }
  }
}

extension DomainBlockMapper on domain.Block {
  IsarBlock toIsar() {
    return map(
      text: (b) => IsarBlock()
        ..id = b.id
        ..type = IsarBlockType.text
        ..data = b.data
        ..orderIndex = b.orderIndex,
      image: (b) => IsarBlock()
        ..id = b.id
        ..type = IsarBlockType.image
        ..data = b.data
        ..orderIndex = b.orderIndex,
      checkbox: (b) => IsarBlock()
        ..id = b.id
        ..type = IsarBlockType.todo
        ..data = b.data
        ..isChecked = b.isChecked
        ..orderIndex = b.orderIndex,
    );
  }
}
