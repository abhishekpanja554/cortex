import 'dart:io';

import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/core/perf/perf_seeder.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/note_body_codec.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('perf_seeder_test_');
  });

  tearDown(() async {
    await db.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('PerfSeeder specifications', () {
    test('produces exactly count rows, none dirty, and none deleted', () async {
      const count = 200;
      final seeder = PerfSeeder(db, tempDir, seed: 123);
      final inserted = await seeder.seed(count: count);

      expect(inserted, count);

      final rows = await db.select(db.notes).get();
      expect(rows.length, count);

      for (final row in rows) {
        expect(row.titleDirty, isFalse, reason: 'titleDirty should be false for note ${row.id}');
        expect(row.bodyDirty, isFalse, reason: 'bodyDirty should be false for note ${row.id}');
        expect(row.deletedAt, isNull, reason: 'deletedAt should be null for note ${row.id}');
      }
    });

    test('for every seeded body, serialize(parse(body)) == body', () async {
      const count = 200;
      final seeder = PerfSeeder(db, tempDir, seed: 456);
      await seeder.seed(count: count);

      final rows = await db.select(db.notes).get();
      expect(rows.length, count);

      const codec = NoteBodyCodec();
      for (final row in rows) {
        final parsed = codec.parse(row.body);
        final roundTripped = codec.serialize(parsed);
        expect(
          roundTripped,
          equals(row.body),
          reason: 'Body for note ${row.id} must round-trip cleanly without mutating',
        );
      }
    });

    test('seeding twice with the same seed gives identical IDs, titles and bodies', () async {
      final db1 = AppDatabase.forTesting(NativeDatabase.memory());
      final tempDir1 = Directory.systemTemp.createTempSync('perf_seeder_seed1_');
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      final tempDir2 = Directory.systemTemp.createTempSync('perf_seeder_seed2_');

      addTearDown(() async {
        await db1.close();
        await db2.close();
        try {
          tempDir1.deleteSync(recursive: true);
          tempDir2.deleteSync(recursive: true);
        } catch (_) {}
      });

      const count = 150;
      const testSeed = 789;

      final seeder1 = PerfSeeder(db1, tempDir1, seed: testSeed);
      await seeder1.seed(count: count);

      final seeder2 = PerfSeeder(db2, tempDir2, seed: testSeed);
      await seeder2.seed(count: count);

      final rows1 = await db1.select(db1.notes).get();
      final rows2 = await db2.select(db2.notes).get();

      expect(rows1.length, count);
      expect(rows2.length, count);

      for (int i = 0; i < count; i++) {
        expect(rows1[i].id, equals(rows2[i].id), reason: 'Note $i id mismatch');
        expect(rows1[i].title, equals(rows2[i].title), reason: 'Note $i title mismatch');
        expect(rows1[i].body, equals(rows2[i].body), reason: 'Note $i body mismatch');
      }
    });

    test('length mix is roughly right: about 60% short and at least one note over 8,000 characters', () async {
      const count = 1000;
      final seeder = PerfSeeder(db, tempDir, seed: 42);
      await seeder.seed(count: count);

      final rows = await db.select(db.notes).get();
      expect(rows.length, count);

      int shortCount = 0;
      int over8kCount = 0;

      for (final row in rows) {
        final len = row.body.length;
        // Short notes target 50-300 characters, allow slight variance up to 350 for padding
        if (len <= 350) {
          shortCount++;
        }
        if (len >= 8000) {
          over8kCount++;
        }
      }

      // About 60% short within a 10% tolerance (50% to 70%)
      final shortFraction = shortCount / count;
      expect(shortFraction, inInclusiveRange(0.50, 0.70),
          reason: 'Expected ~60% short notes, got ${(shortFraction * 100).toStringAsFixed(1)}%');

      // At least one note over 8,000 characters
      expect(over8kCount, greaterThanOrEqualTo(1),
          reason: 'Expected at least one note over 8,000 characters, got $over8kCount');
    });

    test('writes realistic sample photo to attachments/perf_sample.jpg (>100KB) and references it with attachments/ prefix', () async {
      const count = 300;
      final seeder = PerfSeeder(db, tempDir, seed: 101);
      await seeder.seed(count: count);

      final sampleFile = File('${tempDir.path}/attachments/perf_sample.jpg');
      expect(sampleFile.existsSync(), isTrue, reason: 'attachments/perf_sample.jpg must exist');
      final fileSize = sampleFile.lengthSync();
      expect(fileSize, greaterThan(100 * 1024),
          reason: 'Sample image must be realistic size (>100 KB), was $fileSize bytes');

      // Find notes containing an image block
      final rows = await db.select(db.notes).get();
      const codec = NoteBodyCodec();
      final imageNotes = rows.where((r) => r.body.contains('perf_sample.jpg')).toList();
      expect(imageNotes, isNotEmpty, reason: 'At least one note in 300 should have an image');

      for (final row in imageNotes) {
        final blocks = codec.parse(row.body);
        final imageBlocks = blocks.whereType<ImageBlock>().toList();
        expect(imageBlocks, isNotEmpty);
        for (final img in imageBlocks) {
          expect(img.data, 'attachments/perf_sample.jpg',
              reason: 'AttachmentImage requires attachments/ prefix to resolve within documentsDir');
        }
      }
    });
  });
}

