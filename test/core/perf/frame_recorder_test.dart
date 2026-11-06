import 'package:cortex/core/perf/frame_recorder.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FrameReport and FrameRecorder', () {
    test('empty recorder produces zeroed FrameReport', () {
      final recorder = FrameRecorder();
      final report = recorder.stop();

      expect(report.frames, 0);
      expect(report.jankyFrames16ms, 0);
      expect(report.jankyFrames8ms, 0);
      expect(report.jankyTotal16ms, 0);
      expect(report.jankyTotal8ms, 0);
      expect(report.p90Build, Duration.zero);
      expect(report.p90Raster, Duration.zero);
      expect(report.p90Total, Duration.zero);
      expect(report.worst, Duration.zero);

      final json = report.toJson();
      expect(json['frames'], 0);
      expect(json['janky_16ms'], 0);
      expect(json['janky_8ms'], 0);
      expect(json['janky_total_16ms'], 0);
      expect(json['janky_total_8ms'], 0);
      expect(json['p90_build_ms'], 0.0);
      expect(json['p90_raster_ms'], 0.0);
      expect(json['p90_total_ms'], 0.0);
      expect(json['worst_frame_ms'], 0.0);
    });

    test('toJson produces all required total and build/raster fields', () {
      final report = FrameReport(
        frames: 100,
        jankyFrames16ms: 0,
        jankyFrames8ms: 2,
        jankyTotal16ms: 13,
        jankyTotal8ms: 25,
        p90Build: const Duration(milliseconds: 3),
        p90Raster: const Duration(milliseconds: 4),
        p90Total: const Duration(milliseconds: 35),
        worst: const Duration(milliseconds: 72),
      );

      final json = report.toJson();
      expect(json['frames'], 100);
      expect(json['janky_16ms'], 0);
      expect(json['janky_8ms'], 2);
      expect(json['janky_total_16ms'], 13);
      expect(json['janky_total_8ms'], 25);
      expect(json['p90_build_ms'], 3.0);
      expect(json['p90_raster_ms'], 4.0);
      expect(json['p90_total_ms'], 35.0);
      expect(json['worst_frame_ms'], 72.0);
    });

    test('FrameTiming with main thread stall reflects in janky_total but not build/raster jank', () {
      // In Flutter, FrameTiming timestamps are in microseconds:
      // vsyncStart: 0
      // buildStart: 30000 (30ms stall before build starts)
      // buildFinish: 32000 (2ms build duration)
      // rasterStart: 32000
      // rasterFinish: 34000 (2ms raster duration)
      // Total span: 34000us (34ms > 16ms), but build=2ms and raster=2ms (both < 16ms)
      final timing = FrameTiming(
        vsyncStart: 0,
        buildStart: 30000,
        buildFinish: 32000,
        rasterStart: 32000,
        rasterFinish: 34000,
        rasterFinishWallTime: 34000,
      );

      expect(timing.buildDuration.inMilliseconds, 2);
      expect(timing.rasterDuration.inMilliseconds, 2);
      expect(timing.totalSpan.inMilliseconds, 34);

      final recorder = FrameRecorder();
      recorder.start();
      recorder.addTimings([timing]);
      final report = recorder.stop();

      expect(report.frames, 1);
      // Main-thread stall should NOT show in build/raster jank:
      expect(report.jankyFrames16ms, 0);
      // But it MUST show in totalSpan jank:
      expect(report.jankyTotal16ms, 1);
      expect(report.jankyTotal8ms, 1);
      expect(report.worst.inMilliseconds, 34);
      expect(report.p90Total.inMilliseconds, 34);
    });
  });
}
