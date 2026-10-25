import 'dart:developer';
import 'package:flutter/foundation.dart';

class PerfStats {
  final int samples;
  final Duration p50;
  final Duration p90;
  final Duration max;
  final int? lastCount;

  PerfStats({
    required this.samples,
    required this.p50,
    required this.p90,
    required this.max,
    this.lastCount,
  });

  @override
  String toString() =>
      'PerfStats(samples: $samples, p50: ${p50.inMicroseconds}µs, p90: ${p90.inMicroseconds}µs, max: ${max.inMicroseconds}µs, lastCount: $lastCount)';

  Map<String, dynamic> toJson() => {
    'samples': samples,
    'p50': p50.inMicroseconds,
    'p90': p90.inMicroseconds,
    'max': max.inMicroseconds,
    'p50_us': p50.inMicroseconds,
    'p90_us': p90.inMicroseconds,
    'max_us': max.inMicroseconds,
    'p50_ms': p50.inMicroseconds / 1000.0,
    'p90_ms': p90.inMicroseconds / 1000.0,
    'max_ms': max.inMicroseconds / 1000.0,
    if (lastCount != null) 'lastCount': lastCount,
  };
}

class Perf {
  static bool enabled = !kReleaseMode;
  static const int _maxSamples = 200;

  static final Map<String, List<Duration>> _records = {};
  static final Map<String, int?> _lastCounts = {};
  static Stopwatch? _startupStopwatch;

  /// Starts the stopwatch measuring cold start to first notes list.
  /// Called at the very top of `main()`.
  static void startStartupWatch() {
    _startupStopwatch = Stopwatch()..start();
  }

  /// Records `startup.toFirstList` when the first notes update is handled.
  static void markFirstListHandled() {
    if (_startupStopwatch != null && _startupStopwatch!.isRunning) {
      _startupStopwatch!.stop();
      record('startup.toFirstList', _startupStopwatch!.elapsed);
      _startupStopwatch = null;
    }
  }

  @visibleForTesting
  static Stopwatch? get startupStopwatch => _startupStopwatch;

  static T measure<T>(String name, T Function() body, {int? count}) {
    if (!enabled) return body();
    
    final stopwatch = Stopwatch()..start();
    
    final result = Timeline.timeSync(name, body);
    
    stopwatch.stop();
    record(name, stopwatch.elapsed, count: count);
    
    return result;
  }

  static Future<T> measureAsync<T>(String name, Future<T> Function() body, {int? count}) async {
    if (!enabled) return body();
    
    final task = TimelineTask()..start(name);
    final stopwatch = Stopwatch()..start();
    
    try {
      return await body();
    } finally {
      stopwatch.stop();
      task.finish();
      record(name, stopwatch.elapsed, count: count);
    }
  }

  static void record(String name, Duration d, {int? count}) {
    if (!enabled) return;
    
    final records = _records.putIfAbsent(name, () => []);
    records.add(d);
    
    if (records.length > _maxSamples) {
      records.removeAt(0);
    }
    
    if (count != null) {
      _lastCounts[name] = count;
    }
  }

  static Map<String, PerfStats> summary() {
    final result = <String, PerfStats>{};
    if (!enabled) return result;

    for (final entry in _records.entries) {
      final name = entry.key;
      final durations = List<Duration>.from(entry.value)..sort();
      final length = durations.length;

      if (length == 0) continue;

      result[name] = PerfStats(
        samples: length,
        p50: durations[(length * 0.5).toInt()],
        p90: durations[(length * 0.9).toInt()],
        max: durations.last,
        lastCount: _lastCounts[name],
      );
    }
    
    return result;
  }

  static Map<String, dynamic> toJson({Map<String, dynamic>? extra}) {
    final s = summary();
    final perfMap = <String, dynamic>{
      for (final entry in s.entries)
        entry.key: entry.value.toJson(),
    };
    return {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'perf': perfMap,
      ...perfMap,
      if (extra != null) ...extra,
    };
  }

  static void reset() {
    _records.clear();
    _lastCounts.clear();
    _startupStopwatch = null;
  }
}