import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:uuid/uuid.dart';

class NoteBodyCodec {
  const NoteBodyCodec();

  List<Block> parse(String body) {
    if (body.isEmpty) {
      return [Block.text(id: const Uuid().v4(), data: '')];
    }

    final lines = body.split('\n');
    final blocks = <Block>[];

    List<String> currentTextLines = [];

    void flushText() {
      if (currentTextLines.isNotEmpty) {
        blocks.add(
          Block.text(id: const Uuid().v4(), data: currentTextLines.join('\n')),
        );
        currentTextLines.clear();
      }
    }

    for (var line in lines) {
      if (line.startsWith('- [ ] ') || line.startsWith('- [x] ')) {
        flushText();
        final isChecked = line.startsWith('- [x] ');
        final text = line.substring(6);
        blocks.add(
          Block.checkbox(
            id: const Uuid().v4(),
            data: text,
            isChecked: isChecked,
          ),
        );
      } else if (line.startsWith('![](<') && line.endsWith('>)')) {
        flushText();
        final path = line.substring(5, line.length - 2);
        blocks.add(Block.image(id: const Uuid().v4(), data: path));
      } else {
        if (line.startsWith('\\')) {
          int slashCount = 0;
          for (int i = 0; i < line.length; i++) {
            if (line[i] == '\\')
              slashCount++;
            else
              break;
          }
          final unescaped = line.substring(slashCount);
          if (_isSpecial(unescaped)) {
            currentTextLines.add(line.substring(1));
            continue;
          }
        }
        currentTextLines.add(line);
      }
    }

    flushText();
    return blocks;
  }

  String serialize(List<Block> blocks) {
    final List<String> parts = [];
    for (final b in blocks) {
      if (b is TextBlock) {
        final lines = b.data.split('\n');
        for (var line in lines) {
          int slashCount = 0;
          for (int i = 0; i < line.length; i++) {
            if (line[i] == '\\') {
              slashCount++;
            } else {
              break;
            }
          }
          final afterSlashes = line.substring(slashCount);
          if (_isSpecial(afterSlashes)) {
            parts.add('\\' + line);
          } else {
            parts.add(line);
          }
        }
      } else if (b is CheckboxBlock) {
        final text = b.data.replaceAll('\n', ' ');
        parts.add('- [${b.isChecked ? 'x' : ' '}] $text');
      } else if (b is ImageBlock) {
        parts.add('![](<${b.data}>)');
      }
    }
    return parts.join('\n');
  }

  bool _isSpecial(String line) {
    if (line.startsWith('- [ ] ') || line.startsWith('- [x] ')) {
      return true;
    }
    if (line.startsWith('![](<') && line.endsWith('>)')) {
      return true;
    }
    return false;
  }
}
