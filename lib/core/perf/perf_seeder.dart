import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// Adjust these imports to match your project structure
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/core/perf/perf_sample_image.dart';
import 'package:cortex/features/notes/domain/entities/note_preview_data.dart';
import 'package:cortex/features/notes/domain/note_body_codec.dart';

class PerfSeeder {
  PerfSeeder(this._db, this._docsDir, {int seed = 42}) 
      : _rand = Random(seed);

  final AppDatabase _db;
  final Directory _docsDir;
  final Random _rand;
  
  // v5 UUID requires a namespace. We use the standard URL namespace here.
  final Uuid _uuid = const Uuid();

  Future<int> seed({int count = 10000, void Function(int done)? onProgress}) async {
    await _setupSampleImage();

    final now = clock.now().toUtc();
    final threeYears = const Duration(days: 365 * 3);
    const codec = NoteBodyCodec();
    
    var chunk = <NotesCompanion>[];
    int inserted = 0;

    for (int i = 0; i < count; i++) {
      final id = _uuid.v5(Namespace.url.value, 'perf-$i');

      // Titles: 2-6 words. ~3% empty.
      final title = _rand.nextDouble() < 0.03
          ? ''
          : _generateWords(2 + _rand.nextInt(5));

      // Determine target body length based on the requested distribution
      final rLen = _rand.nextDouble();
      int targetChars;
      if (rLen < 0.60) {
        targetChars = 50 + _rand.nextInt(300 - 50);      // 60%: 50–300
      } else if (rLen < 0.90) {
        targetChars = 300 + _rand.nextInt(2000 - 300);   // 30%: 300–2,000
      } else if (rLen < 0.99) {
        targetChars = 2000 + _rand.nextInt(8000 - 2000); // 9%: 2,000–8,000
      } else {
        targetChars = 8000 + _rand.nextInt(20000 - 8000);// 1%: 8,000–20,000
      }

      final hasChecklist = _rand.nextDouble() < 0.20;
      final hasImage = _rand.nextDouble() < 0.02;

      // Construct codec-compliant blocks so loading the note doesn't trigger a dirty-save
      final blocks = _generateBlocks(targetChars, hasChecklist, hasImage);
      final bodyStr = codec.serialize(blocks);

      // Timestamps spread over the last 3 years
      final createdSecondsAgo = _rand.nextInt(threeYears.inSeconds);
      final createdAt = now.subtract(Duration(seconds: createdSecondsAgo));
      final updateDelaySeconds =
          createdSecondsAgo > 0 ? _rand.nextInt(createdSecondsAgo) : 0;
      final updatedAt = createdAt.add(Duration(seconds: updateDelaySeconds));

      // Compute preview once when saved/seeded
      final preview = computePreview(bodyStr);

      // Create row with strictly NO dirty flags to avoid triggering network sync
      chunk.add(NotesCompanion.insert(
        id: Value(id),
        title: Value(title),
        body: Value(bodyStr),
        previewText: Value(preview.previewText),
        firstImagePath: Value(preview.firstImagePath),
        previewTodos: Value(preview.previewTodos),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        titleDirty: const Value(false),
        bodyDirty: const Value(false),
        localRevision: const Value(0),
      ));

      // Batch insert every 1,000 records
      if (chunk.length == 1000) {
        await _db.batch((batch) => batch.insertAll(_db.notes, chunk, mode: InsertMode.insertOrReplace));
        inserted += chunk.length;
        chunk.clear();
        onProgress?.call(inserted);
      }
    }

    // Insert remaining rows
    if (chunk.isNotEmpty) {
      await _db.batch((batch) => batch.insertAll(_db.notes, chunk, mode: InsertMode.insertOrReplace));
      inserted += chunk.length;
      onProgress?.call(inserted);
    }

    return inserted;
  }

  List<Block> _generateBlocks(int targetChars, bool hasChecklist, bool hasImage) {
    final blocks = <Block>[];
    int currentChars = 0;

    if (hasImage) {
      blocks.add(ImageBlock(id: '${_rand.nextInt(500000)}', data: 'attachments/perf_sample.jpg'));
      currentChars += 20; // Rough character equivalent in markdown
    }

    if (hasChecklist && currentChars < targetChars) {
      final maxItems = targetChars <= 300 ? (1 + _rand.nextInt(3)) : (3 + _rand.nextInt(13));
      for (int i = 0; i < maxItems && currentChars < targetChars; i++) {
        final wordsCount = targetChars <= 300 ? (2 + _rand.nextInt(3)) : (3 + _rand.nextInt(8));
        final text = _generateWords(wordsCount);
        blocks.add(CheckboxBlock(
          id: '${_rand.nextInt(500000)}',
          data: text, 
          isChecked: _rand.nextBool(),
        ));
        currentChars += text.length + 6;
      }
    }

    // Fill the remaining length with text blocks (paragraphs)
    while (currentChars < targetChars) {
      final remaining = targetChars - currentChars;
      final wordCount = remaining <= 100
          ? (3 + _rand.nextInt(10))
          : (10 + _rand.nextInt(31));
      final paragraph = _generateWords(wordCount);
      blocks.add(TextBlock(id: '${_rand.nextInt(500000)}', data: paragraph));
      currentChars += paragraph.length + 2; 
    }

    return blocks;
  }

  String _generateWords(int count) {
    final buffer = StringBuffer();
    for (int i = 0; i < count; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(_wordList[_rand.nextInt(_wordList.length)]);
    }
    // Capitalize first letter and add a period if it's a longer string
    final str = buffer.toString();
    if (str.isEmpty) return str;
    
    return str[0].toUpperCase() + str.substring(1) + (count > 5 ? '.' : '');
  }

  Future<void> _setupSampleImage() async {
    final attachmentsDir = Directory('${_docsDir.path}/attachments');
    if (!await attachmentsDir.exists()) {
      await attachmentsDir.create(recursive: true);
    }
    
    final file = File('${attachmentsDir.path}/perf_sample.jpg');
    // Realistic photo (~180 KB, 2000x1500 pixels) to test image decoding during scrolling.
    if (!await file.exists() || (await file.length()) < 50000) {
      final bytes = base64Decode(kPerfSampleImageBase64.replaceAll('\n', '').trim());
      await file.writeAsBytes(bytes);
    }
  }

  // A couple hundred varied words to simulate real content distribution
  static const List<String> _wordList = [
    'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'I', 'it', 'for', 
    'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at', 'this', 'but', 'his', 
    'by', 'from', 'they', 'we', 'say', 'her', 'she', 'or', 'an', 'will', 'my', 
    'one', 'all', 'would', 'there', 'their', 'what', 'so', 'up', 'out', 'if', 
    'about', 'who', 'get', 'which', 'go', 'me', 'when', 'make', 'can', 'like', 
    'time', 'no', 'just', 'him', 'know', 'take', 'people', 'into', 'year', 'your', 
    'good', 'some', 'could', 'them', 'see', 'other', 'than', 'then', 'now', 'look', 
    'only', 'come', 'its', 'over', 'think', 'also', 'back', 'after', 'use', 'two', 
    'how', 'our', 'work', 'first', 'well', 'way', 'even', 'new', 'want', 'because', 
    'any', 'these', 'give', 'day', 'most', 'us', 'project', 'meeting', 'design', 
    'review', 'code', 'database', 'system', 'architecture', 'user', 'client', 
    'product', 'strategy', 'metrics', 'growth', 'data', 'analysis', 'report', 
    'development', 'research', 'market', 'feature', 'launch', 'budget', 'team',
    'idea', 'notes', 'action', 'sync', 'priority', 'task', 'goal', 'schedule', 
    'planning', 'infrastructure', 'server', 'application', 'mobile', 'web'
  ];
}