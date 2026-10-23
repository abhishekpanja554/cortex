import 'dart:io';
import 'package:dio/dio.dart';

/// Failures that can occur during cortex-ai communication.
sealed class AiFailure implements Exception {
  const AiFailure();
}

/// Cortex-ai service is down or unreachable (connection refused, connect timeout).
/// Spec §9: chat fails clearly, and notes and sync keep working.
class AiUnavailable extends AiFailure {
  final String? message;
  const AiUnavailable([this.message]);

  @override
  String toString() => 'AiUnavailable: ${message ?? 'cortex-ai is unavailable'}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiUnavailable && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Rate limit exceeded (HTTP 429), carrying optional retry duration from header.
class RateLimited extends AiFailure {
  final Duration? retryAfter;
  const RateLimited([this.retryAfter]);

  @override
  String toString() => 'RateLimited(retryAfter: $retryAfter)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RateLimited &&
          runtimeType == other.runtimeType &&
          retryAfter == other.retryAfter;

  @override
  int get hashCode => retryAfter.hashCode;
}

/// 5xx server error, or broken/interrupted stream.
class AiServerError extends AiFailure {
  final String? message;
  final int? statusCode;
  const AiServerError([this.message, this.statusCode]);

  @override
  String toString() =>
      'AiServerError(statusCode: $statusCode, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiServerError &&
          runtimeType == other.runtimeType &&
          statusCode == other.statusCode &&
          message == other.message;

  @override
  int get hashCode => Object.hash(statusCode, message);
}

/// Maps a [DioException] to an appropriate [AiFailure].
AiFailure mapDioExceptionToAiFailure(DioException e) {
  final response = e.response;
  final statusCode = response?.statusCode;

  if (statusCode == 429) {
    final retryAfter = parseRetryAfterHeader(response?.headers);
    return RateLimited(retryAfter);
  }

  if (statusCode != null && statusCode >= 500 && statusCode < 600) {
    return AiServerError(response?.statusMessage ?? 'Server error', statusCode);
  }

  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.error is SocketException) {
    return AiUnavailable(e.message ?? 'cortex-ai is unavailable');
  }

  if (e.type == DioExceptionType.receiveTimeout) {
    return const AiServerError('Stream receive timed out');
  }

  return AiServerError(e.message ?? 'Unknown network error', statusCode);
}

/// Parses the Retry-After header as seconds or HTTP date.
Duration? parseRetryAfterHeader(Headers? headers) {
  if (headers == null) return null;
  final value = headers.value('retry-after') ?? headers.value('Retry-After');
  if (value == null || value.trim().isEmpty) return null;
  final trimmed = value.trim();
  final seconds = int.tryParse(trimmed);
  if (seconds != null) {
    return Duration(seconds: seconds);
  }
  try {
    final httpDate = HttpDate.parse(trimmed);
    final diff = httpDate.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  } catch (_) {
    return null;
  }
}
