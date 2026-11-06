import 'dart:math';

import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/note_body_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = NoteBodyCodec();

  void expectBlocksMatch(List<Block> actual, List<Block> expected) {
    expect(actual.length, expected.length);
    for (int i = 0; i < actual.length; i++) {
      final a = actual[i];
      final e = expected[i];

      expect(a.runtimeType, e.runtimeType);

      if (a is TextBlock && e is TextBlock) {
        expect(a.data, e.data);
      } else if (a is CheckboxBlock && e is CheckboxBlock) {
        expect(a.data, e.data);
        expect(a.isChecked, e.isChecked);
      } else if (a is ImageBlock && e is ImageBlock) {
        expect(a.data, e.data);
      } else {
        fail('Block types do not match or unsupported block type.');
      }
    }
  }

  group('NoteBodyCodec Round-trip Tests', () {
    final roundTripCases = [
      '',
      '\n',
      '\n\n',
      'abc\n',
      '- [ ] a\n\n- [x] b',
      '- [X] upper',
      '* [ ] star',
      '![](<p.png>)',
      '\\- [ ] escaped',
      '\\\\- [ ] double',
      'hello\n- [ ] world\n![](</path/to/image.png>)\nmulti\nline\ntext\n- [x] done',
      '![](<image path with spaces and ).png>)',
    ];

    for (final s in roundTripCases) {
      test('round trips exactly: ${s.replaceAll('\n', r'\n')}', () {
        final parsed = codec.parse(s);
        final serialized = codec.serialize(parsed);
        expect(serialized, s);
      });
    }
  });

  group('NoteBodyCodec Structure Tests', () {
    test('mixed body parses correctly', () {
      const s =
          'hello\n- [ ] world\n![](</path/to/image.png>)\nmulti\nline\ntext\n- [x] done';
      final parsed = codec.parse(s);

      expectBlocksMatch(parsed, const [
        Block.text(id: '', data: 'hello'),
        Block.checkbox(id: '', data: 'world', isChecked: false),
        Block.image(id: '', data: '/path/to/image.png'),
        Block.text(id: '', data: 'multi\nline\ntext'),
        Block.checkbox(id: '', data: 'done', isChecked: true),
      ]);
    });

    test('text block with escaped checkbox on third line parses correctly', () {
      const s = 'line 1\nline 2\n\\- [ ] x';
      final parsed = codec.parse(s);

      expectBlocksMatch(parsed, const [
        Block.text(id: '', data: 'line 1\nline 2\n- [ ] x'),
      ]);
    });

    test('image path with a space and a ) round-trips correctly', () {
      const s = '![](<path with space and ).png>)';
      final parsed = codec.parse(s);

      expectBlocksMatch(parsed, const [
        Block.image(id: '', data: 'path with space and ).png'),
      ]);
      expect(codec.serialize(parsed), s);
    });

    test('checkbox serialization replaces newline with space', () {
      final blocks = [
        const Block.checkbox(
          id: '1',
          data: 'multi\nline\ncheckbox',
          isChecked: false,
        ),
      ];
      final serialized = codec.serialize(blocks);
      expect(serialized, '- [ ] multi line checkbox');
    });
  });

  test('Fuzz test for random note bodies', () {
    final rand = Random(42);
    final pieces = [
      '',
      '\n',
      'a text line',
      '\\- [ ] escaped',
      '\\\\- [ ] double escaped',
      '- [ ] checkbox',
      '- [x] done checkbox',
      '![](<path.png>)',
      '![](<path with spaces.png>)',
      '![](<a) and b>)',
      '![not an image](a.png)',
      '![](<abc.png>) and some text',
      'some text ![](<abc.png>)',
    ];

    for (int i = 0; i < 200000; i++) {
      final bodyPieces = List.generate(
        rand.nextInt(10) + 1,
        (_) => pieces[rand.nextInt(pieces.length)],
      );
      final s = bodyPieces.join('\n');

      final parsed = codec.parse(s);
      final serialized = codec.serialize(parsed);
      expect(serialized, s, reason: 'Failed on iteration $i with body: $s');
    }
  });
}
