import 'dart:convert';
import 'dart:io';

import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/core/database/app_database_provider.dart';
import 'package:cortex/core/perf/perf.dart';
import 'package:cortex/core/perf/perf_providers.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/auth/presentation/current_user_provider.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/security/services/security_service.dart';
import 'package:cortex/features/settings/presentation/screens/settings_screen.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecurityService extends Mock implements SecurityService {}
class MockNoteRepository extends Mock implements NoteRepository {}
class MockSyncScheduler extends Mock implements SyncScheduler {}

void main() {
  late MockSecurityService mockSecurityService;
  late MockNoteRepository mockNoteRepository;
  late MockSyncScheduler mockSyncScheduler;
  late AppDatabase testDb;
  late Directory tempDir;

  setUp(() {
    mockSecurityService = MockSecurityService();
    mockNoteRepository = MockNoteRepository();
    mockSyncScheduler = MockSyncScheduler();
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('cortex_perf_test_');

    when(() => mockSecurityService.isPrivateModeEnabled).thenAnswer((_) async => false);
    when(() => mockSecurityService.hasAppPin).thenAnswer((_) async => false);
    when(() => mockNoteRepository.watchAllNotes(limit: any(named: 'limit'))).thenAnswer((_) => Stream.value([]));
    when(() => mockNoteRepository.watchNoteCount()).thenAnswer((_) => Stream.value(0));
    when(() => mockNoteRepository.unsyncedCount()).thenAnswer((_) async => 0);
    when(() => mockSyncScheduler.requestSync()).thenReturn(null);

    Perf.reset();
  });

  tearDown(() async {
    await testDb.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  Widget buildSettingsApp({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: SettingsScreen(),
        ),
      ),
    );
  }

  testWidgets('Developer menu displays all 4 actions when not in release mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(mockSecurityService),
        noteRepositoryProvider.overrideWithValue(mockNoteRepository),
        syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
        appDatabaseProvider.overrideWithValue(testDb),
        documentsDirectoryProvider.overrideWithValue(tempDir),
        currentUserEmailProvider.overrideWith((ref) => 'dev@cortex.app'),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(buildSettingsApp(container: container));
    await tester.pumpAndSettle();

    // Verify Developer Group Header and Actions
    expect(find.text('Seed 10,000 notes'), findsOneWidget);
    expect(find.text('Shows progress, then the time it took'), findsOneWidget);

    expect(find.text('Start frame recording'), findsOneWidget);
    expect(find.text('Wraps a scenario such as scrolling or typing'), findsOneWidget);

    expect(find.text('Export perf summary'), findsOneWidget);
    expect(find.text('Writes perf_summary.json (0.4)'), findsOneWidget);

    expect(find.text('Reset perf stats'), findsOneWidget);
    expect(find.text('Clears samples between runs'), findsOneWidget);
  });

  testWidgets('Start and stop frame recording toggles state and displays report', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(mockSecurityService),
        noteRepositoryProvider.overrideWithValue(mockNoteRepository),
        syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
        appDatabaseProvider.overrideWithValue(testDb),
        documentsDirectoryProvider.overrideWithValue(tempDir),
        currentUserEmailProvider.overrideWith((ref) => 'dev@cortex.app'),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(buildSettingsApp(container: container));
    await tester.pumpAndSettle();

    // Tap to Start frame recording
    final startButton = find.text('Start frame recording');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    // Should now show Stop frame recording and REC badge
    expect(find.text('Stop frame recording'), findsOneWidget);
    expect(find.text('REC'), findsOneWidget);
    expect(find.textContaining('Recording active'), findsOneWidget);

    // Tap to Stop frame recording
    final stopButton = find.text('Stop frame recording');
    await tester.ensureVisible(stopButton);
    await tester.tap(stopButton);
    await tester.pumpAndSettle();

    // Should return to Start frame recording
    expect(find.text('Start frame recording'), findsOneWidget);
    expect(find.text('REC'), findsNothing);
  });

  testWidgets('Reset perf stats clears samples between runs', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(mockSecurityService),
        noteRepositoryProvider.overrideWithValue(mockNoteRepository),
        syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
        appDatabaseProvider.overrideWithValue(testDb),
        documentsDirectoryProvider.overrideWithValue(tempDir),
        currentUserEmailProvider.overrideWith((ref) => 'dev@cortex.app'),
      ],
    );
    addTearDown(container.dispose);

    // Record sample metrics
    Perf.record('search.filterSort', const Duration(milliseconds: 15));
    Perf.record('notes.diffCache', const Duration(milliseconds: 5));
    expect(Perf.summary().containsKey('search.filterSort'), isTrue);

    await tester.pumpWidget(buildSettingsApp(container: container));
    await tester.pumpAndSettle();

    // Tap Reset perf stats
    final resetButton = find.text('Reset perf stats');
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    // Metrics should be cleared
    expect(Perf.summary().isEmpty, isTrue);
    expect(find.text('Perf stats reset'), findsOneWidget);
  });

  testWidgets('Export perf summary writes perf_summary.json', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(mockSecurityService),
        noteRepositoryProvider.overrideWithValue(mockNoteRepository),
        syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
        appDatabaseProvider.overrideWithValue(testDb),
        documentsDirectoryProvider.overrideWithValue(tempDir),
        currentUserEmailProvider.overrideWith((ref) => 'dev@cortex.app'),
      ],
    );
    addTearDown(container.dispose);

    // Record a sample metric
    Perf.record('notes.parseIsolate', const Duration(milliseconds: 25));

    await tester.pumpWidget(buildSettingsApp(container: container));
    await tester.pumpAndSettle();

    // Tap Export perf summary
    final exportButton = find.text('Export perf summary');
    await tester.ensureVisible(exportButton);
    await tester.runAsync(() async {
      await tester.tap(exportButton);
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Verify file written in documents directory and NOT in current working directory
    final exportedFile = File('${tempDir.path}/perf_summary.json');
    expect(exportedFile.existsSync(), isTrue);
    expect(File('perf_summary.json').existsSync(), isFalse,
        reason: 'Export should not write to current working directory');

    final content = exportedFile.readAsStringSync();
    final json = jsonDecode(content) as Map<String, dynamic>;
    expect(json.containsKey('notes.parseIsolate'), isTrue);
    expect(find.textContaining('Exported perf summary to perf_summary.json'), findsOneWidget);
  });

  test('Seed notes seeds data and displays elapsed time', () async {
    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(mockSecurityService),
        noteRepositoryProvider.overrideWithValue(mockNoteRepository),
        syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
        appDatabaseProvider.overrideWithValue(testDb),
        documentsDirectoryProvider.overrideWithValue(tempDir),
        currentUserEmailProvider.overrideWith((ref) => 'dev@cortex.app'),
      ],
    );
    addTearDown(container.dispose);

    final elapsed = await container.read(developerStateProvider.notifier).seedNotes(count: 20);
    expect(elapsed.inMilliseconds, greaterThanOrEqualTo(0));

    // Verify notes inserted in database
    final rows = await testDb.select(testDb.notes).get();
    expect(rows.length, 20);
  });

  test('Store frame reports by name (scroll, typing) and export all of them', () async {
    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(mockSecurityService),
        noteRepositoryProvider.overrideWithValue(mockNoteRepository),
        syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
        appDatabaseProvider.overrideWithValue(testDb),
        documentsDirectoryProvider.overrideWithValue(tempDir),
        currentUserEmailProvider.overrideWith((ref) => 'dev@cortex.app'),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(developerStateProvider.notifier);

    // 1. Record 'scroll' scenario
    notifier.startFrameRecording('scroll');
    expect(container.read(developerStateProvider).isRecordingFrames, isTrue);
    expect(container.read(developerStateProvider).recordingScenario, 'scroll');
    final scrollReport = notifier.stopFrameRecording();
    expect(scrollReport, isNotNull);

    // 2. Record 'typing' scenario
    notifier.startFrameRecording('typing');
    expect(container.read(developerStateProvider).isRecordingFrames, isTrue);
    expect(container.read(developerStateProvider).recordingScenario, 'typing');
    final typingReport = notifier.stopFrameRecording();
    expect(typingReport, isNotNull);

    // 3. Verify state contains both reports by name
    final state = container.read(developerStateProvider);
    expect(state.frameReports.containsKey('scroll'), isTrue);
    expect(state.frameReports.containsKey('typing'), isTrue);

    // 4. Export perf summary and verify both reports are present in the JSON
    final file = await notifier.exportPerfSummary();
    final jsonContent = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    expect(jsonContent.containsKey('frames'), isTrue);
    final frames = jsonContent['frames'] as Map<String, dynamic>;
    expect(frames.containsKey('scroll'), isTrue, reason: 'frames export must include scroll scenario');
    expect(frames.containsKey('typing'), isTrue, reason: 'frames export must include typing scenario');

    expect(jsonContent.containsKey('frame_reports'), isTrue);
    final frameReports = jsonContent['frame_reports'] as Map<String, dynamic>;
    expect(frameReports.containsKey('scroll'), isTrue);
    expect(frameReports.containsKey('typing'), isTrue);

    final scrollData = frameReports['scroll'] as Map<String, dynamic>;
    expect(scrollData.containsKey('janky_total_16ms'), isTrue);
    expect(scrollData.containsKey('janky_total_8ms'), isTrue);
    expect(scrollData.containsKey('p90_total_ms'), isTrue);
    expect(scrollData.containsKey('janky_16ms'), isTrue);
    expect(scrollData.containsKey('p90_build_ms'), isTrue);
    expect(scrollData.containsKey('p90_raster_ms'), isTrue);
    expect(scrollData.containsKey('worst_frame_ms'), isTrue);
  });

  testWidgets('Export Notes reads full notes from getAllNotesForExport and outputs JSON', (tester) async {
    final now = DateTime.utc(2026, 1, 1);
    final notes = [
      NoteEntity(
        id: 'export-id-1',
        title: 'Export Title 1',
        body: 'Export Full Body 1 with checklist:\n- [x] Done',
        createdAt: now,
        updatedAt: now,
      ),
    ];
    when(() => mockNoteRepository.getAllNotesForExport()).thenAnswer((_) async => notes);

    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(mockSecurityService),
        noteRepositoryProvider.overrideWithValue(mockNoteRepository),
        syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
        appDatabaseProvider.overrideWithValue(testDb),
        documentsDirectoryProvider.overrideWithValue(tempDir),
        currentUserEmailProvider.overrideWith((ref) => 'dev@cortex.app'),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(buildSettingsApp(container: container));
    await tester.pumpAndSettle();

    final exportTile = find.text('Export Notes');
    await tester.ensureVisible(exportTile);
    await tester.runAsync(() async {
      await tester.tap(exportTile);
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    verify(() => mockNoteRepository.getAllNotesForExport()).called(1);
    expect(find.textContaining('Exported 1 note to cortex_backup.json'), findsOneWidget);

    final exportedFile = File('${tempDir.path}/cortex_backup.json');
    expect(exportedFile.existsSync(), isTrue);
    final jsonList = jsonDecode(exportedFile.readAsStringSync()) as List<dynamic>;
    expect(jsonList.length, 1);
    expect(jsonList.first['id'], 'export-id-1');
    expect(jsonList.first['body'], 'Export Full Body 1 with checklist:\n- [x] Done');
  });
}

