import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cortex/core/database/app_database_provider.dart';
import 'package:cortex/core/perf/frame_recorder.dart';
import 'package:cortex/core/perf/perf.dart';
import 'package:cortex/core/perf/perf_seeder.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class DeveloperState {
  final bool isSeeding;
  final int seedProgress;
  final Duration? lastSeedDuration;
  final bool isRecordingFrames;
  final String recordingScenario;
  final Map<String, FrameReport> frameReports;
  final FrameReport? lastFrameReport;
  final bool isExporting;
  final String? lastExportPath;

  const DeveloperState({
    this.isSeeding = false,
    this.seedProgress = 0,
    this.lastSeedDuration,
    this.isRecordingFrames = false,
    this.recordingScenario = 'scroll',
    this.frameReports = const {},
    this.lastFrameReport,
    this.isExporting = false,
    this.lastExportPath,
  });

  DeveloperState copyWith({
    bool? isSeeding,
    int? seedProgress,
    Duration? lastSeedDuration,
    bool? isRecordingFrames,
    String? recordingScenario,
    Map<String, FrameReport>? frameReports,
    FrameReport? lastFrameReport,
    bool? isExporting,
    String? lastExportPath,
    bool clearFrameReport = false,
  }) {
    return DeveloperState(
      isSeeding: isSeeding ?? this.isSeeding,
      seedProgress: seedProgress ?? this.seedProgress,
      lastSeedDuration: lastSeedDuration ?? this.lastSeedDuration,
      isRecordingFrames: isRecordingFrames ?? this.isRecordingFrames,
      recordingScenario: recordingScenario ?? this.recordingScenario,
      frameReports: clearFrameReport ? const {} : (frameReports ?? this.frameReports),
      lastFrameReport: clearFrameReport ? null : (lastFrameReport ?? this.lastFrameReport),
      isExporting: isExporting ?? this.isExporting,
      lastExportPath: lastExportPath ?? this.lastExportPath,
    );
  }
}

final frameRecorderProvider = Provider<FrameRecorder>((ref) {
  return FrameRecorder();
});

final developerStateProvider =
    NotifierProvider<DeveloperNotifier, DeveloperState>(DeveloperNotifier.new);

class DeveloperNotifier extends Notifier<DeveloperState> {
  FrameRecorder get _frameRecorder => ref.read(frameRecorderProvider);

  @override
  DeveloperState build() => const DeveloperState();

  Future<Duration> seedNotes({int count = 10000}) async {
    if (state.isSeeding) return Duration.zero;

    state = state.copyWith(isSeeding: true, seedProgress: 0);
    final stopwatch = Stopwatch()..start();

    try {
      Directory docsDir;
      try {
        docsDir = ref.read(documentsDirectoryProvider);
      } catch (_) {
        docsDir = await getApplicationDocumentsDirectory();
      }

      final db = ref.read(appDatabaseProvider);
      final seeder = PerfSeeder(db, docsDir);

      await seeder.seed(
        count: count,
        onProgress: (done) {
          state = state.copyWith(seedProgress: done);
        },
      );

      stopwatch.stop();
      final elapsed = stopwatch.elapsed;
      state = state.copyWith(
        isSeeding: false,
        seedProgress: count,
        lastSeedDuration: elapsed,
      );
      return elapsed;
    } catch (e) {
      state = state.copyWith(isSeeding: false);
      rethrow;
    }
  }

  void setRecordingScenario(String scenario) {
    if (state.isRecordingFrames) return;
    state = state.copyWith(recordingScenario: scenario);
  }

  void startFrameRecording([String? name]) {
    if (state.isRecordingFrames) return;
    final scenario = name ?? state.recordingScenario;
    _frameRecorder.start();
    state = state.copyWith(
      isRecordingFrames: true,
      recordingScenario: scenario,
    );
  }

  FrameReport stopFrameRecording() {
    final report = _frameRecorder.stop();
    final name = state.recordingScenario;
    final updated = Map<String, FrameReport>.from(state.frameReports);
    updated[name] = report;

    state = state.copyWith(
      isRecordingFrames: false,
      lastFrameReport: report,
      frameReports: updated,
    );
    return report;
  }

  FrameReport? toggleFrameRecording([String? name]) {
    if (state.isRecordingFrames) {
      return stopFrameRecording();
    } else {
      startFrameRecording(name);
      return null;
    }
  }

  Future<File> exportPerfSummary() async {
    state = state.copyWith(isExporting: true);
    try {
      Directory docsDir;
      try {
        docsDir = ref.read(documentsDirectoryProvider);
      } catch (_) {
        docsDir = await getApplicationDocumentsDirectory();
      }

      final frameReportsJson = <String, dynamic>{
        for (final entry in state.frameReports.entries)
          entry.key: entry.value.toJson(),
      };

      final jsonMap = Perf.toJson(
        extra: {
          'frames': frameReportsJson.isNotEmpty
              ? frameReportsJson
              : (state.lastFrameReport != null
                  ? state.lastFrameReport!.toJson()
                  : <String, dynamic>{}),
          'frame_reports': frameReportsJson,
          if (state.lastFrameReport != null)
            'last_frame_report': state.lastFrameReport!.toJson(),
        },
      );

      final jsonContent =
          const JsonEncoder.withIndent('  ').convert(jsonMap);
      final file = File('${docsDir.path}/perf_summary.json');
      await file.writeAsString(jsonContent);

      developer.log('Exported perf summary to ${file.path}');
      state = state.copyWith(isExporting: false, lastExportPath: file.path);
      return file;
    } catch (e) {
      state = state.copyWith(isExporting: false);
      rethrow;
    }
  }

  void resetPerfStats() {
    Perf.reset();
    _frameRecorder.clear();
    state = state.copyWith(clearFrameReport: true);
  }
}
