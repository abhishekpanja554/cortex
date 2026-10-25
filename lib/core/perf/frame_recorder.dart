import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class FrameReport {
  final int frames;
  final int jankyFrames16ms;
  final int jankyFrames8ms;
  final int jankyTotal16ms;
  final int jankyTotal8ms;
  final Duration p90Build;
  final Duration p90Raster;
  final Duration p90Total;
  final Duration worst;

  FrameReport({
    required this.frames,
    required this.jankyFrames16ms,
    required this.jankyFrames8ms,
    this.jankyTotal16ms = 0,
    this.jankyTotal8ms = 0,
    required this.p90Build,
    required this.p90Raster,
    this.p90Total = Duration.zero,
    required this.worst,
  });

  @override
  String toString() {
    return 'FrameReport(\n'
        '  frames: $frames,\n'
        '  janky build/raster (>16ms): $jankyFrames16ms,\n'
        '  janky build/raster (>8ms): $jankyFrames8ms,\n'
        '  janky total (>16ms): $jankyTotal16ms,\n'
        '  janky total (>8ms): $jankyTotal8ms,\n'
        '  p90 build: ${p90Build.inMicroseconds / 1000} ms,\n'
        '  p90 raster: ${p90Raster.inMicroseconds / 1000} ms,\n'
        '  p90 total: ${p90Total.inMicroseconds / 1000} ms,\n'
        '  worst frame: ${worst.inMicroseconds / 1000} ms\n'
        ')';
  }

  Map<String, dynamic> toJson() => {
    'frames': frames,
    'janky_16ms': jankyFrames16ms,
    'janky_8ms': jankyFrames8ms,
    'janky_total_16ms': jankyTotal16ms,
    'janky_total_8ms': jankyTotal8ms,
    'p90_build_ms': p90Build.inMicroseconds / 1000.0,
    'p90_raster_ms': p90Raster.inMicroseconds / 1000.0,
    'p90_total_ms': p90Total.inMicroseconds / 1000.0,
    'worst_frame_ms': worst.inMicroseconds / 1000.0,
  };
}

class FrameRecorder {
  final List<FrameTiming> _timings = [];
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  List<FrameTiming> get timings => List.unmodifiable(_timings);

  void clear() {
    _timings.clear();
  }

  void start() {
    if (_isRecording) return;
    _timings.clear();
    _isRecording = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    _timings.addAll(timings);
  }

  @visibleForTesting
  void addTimings(List<FrameTiming> timings) {
    _onTimings(timings);
  }

  FrameReport stop() {
    if (_isRecording) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _isRecording = false;
    }

    if (_timings.isEmpty) {
      return FrameReport(
        frames: 0,
        jankyFrames16ms: 0,
        jankyFrames8ms: 0,
        jankyTotal16ms: 0,
        jankyTotal8ms: 0,
        p90Build: Duration.zero,
        p90Raster: Duration.zero,
        p90Total: Duration.zero,
        worst: Duration.zero,
      );
    }

    int janky16 = 0;
    int janky8 = 0;
    int jankyTotal16 = 0;
    int jankyTotal8 = 0;
    Duration worstDuration = Duration.zero;

    final buildDurations = <Duration>[];
    final rasterDurations = <Duration>[];
    final totalDurations = <Duration>[];

    for (final timing in _timings) {
      final build = timing.buildDuration;
      final raster = timing.rasterDuration;
      final total = timing.totalSpan;
      
      buildDurations.add(build);
      rasterDurations.add(raster);
      totalDurations.add(total);

      if (build.inMicroseconds > 16000 || raster.inMicroseconds > 16000) {
        janky16++;
      }
      if (build.inMicroseconds > 8000 || raster.inMicroseconds > 8000) {
        janky8++;
      }
      if (total.inMicroseconds > 16000) {
        jankyTotal16++;
      }
      if (total.inMicroseconds > 8000) {
        jankyTotal8++;
      }

      if (total > worstDuration) {
        worstDuration = total;
      }
    }

    buildDurations.sort();
    rasterDurations.sort();
    totalDurations.sort();

    final p90Index = (_timings.length * 0.9).toInt().clamp(0, _timings.length - 1);

    return FrameReport(
      frames: _timings.length,
      jankyFrames16ms: janky16,
      jankyFrames8ms: janky8,
      jankyTotal16ms: jankyTotal16,
      jankyTotal8ms: jankyTotal8,
      p90Build: buildDurations[p90Index],
      p90Raster: rasterDurations[p90Index],
      p90Total: totalDurations[p90Index],
      worst: worstDuration,
    );
  }
}