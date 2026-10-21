import 'package:cortex/features/sync/domain/sync_failure.dart';
import 'package:dio/dio.dart';

enum PushOutcome {
  accepted,
  rejectedStale,
  conflict,
  rejectedDeleted,
}

class PushNoteResult {
  final String id;
  final PushOutcome? titleOutcome;
  final PushOutcome? bodyOutcome;
  final String? titleUpdatedAt;
  final String? bodyUpdatedAt;
  final String? conflictNoteId;
  final bool deleted;

  const PushNoteResult({
    required this.id,
    this.titleOutcome,
    this.bodyOutcome,
    this.titleUpdatedAt,
    this.bodyUpdatedAt,
    this.conflictNoteId,
    this.deleted = false,
  });

  factory PushNoteResult.fromJson(Map<String, dynamic> json) {
    return PushNoteResult(
      id: json['id'] as String,
      titleOutcome: _parseOutcome(json['titleOutcome'] as String?),
      bodyOutcome: _parseOutcome(json['bodyOutcome'] as String?),
      titleUpdatedAt: json['titleUpdatedAt'] as String?,
      bodyUpdatedAt: json['bodyUpdatedAt'] as String?,
      conflictNoteId: json['conflictNoteId'] as String?,
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  static PushOutcome? _parseOutcome(String? str) {
    if (str == null) return null;
    return switch (str.toUpperCase()) {
      'ACCEPTED' => PushOutcome.accepted,
      'REJECTED_STALE' => PushOutcome.rejectedStale,
      'CONFLICT' => PushOutcome.conflict,
      'REJECTED_DELETED' => PushOutcome.rejectedDeleted,
      _ => null,
    };
  }
}

class PulledNote {
  final String id;
  final String? title;
  final String? body;
  final bool deleted;
  final String? titleUpdatedAt;
  final String? bodyUpdatedAt;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final String? conflictOf;
  final String? conflictField;

  const PulledNote({
    required this.id,
    this.title,
    this.body,
    this.deleted = false,
    this.titleUpdatedAt,
    this.bodyUpdatedAt,
    this.updatedAt,
    this.createdAt,
    this.conflictOf,
    this.conflictField,
  });

  factory PulledNote.fromJson(Map<String, dynamic> json) {
    final isDeleted =
        (json['deleted'] as bool? ?? false) || (json['deletedAt'] != null);

    return PulledNote(
      id: json['id'] as String,
      title: json['title'] as String?,
      body: json['body'] as String?,
      deleted: isDeleted,
      titleUpdatedAt: json['titleUpdatedAt'] as String?,
      bodyUpdatedAt: json['bodyUpdatedAt'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String).toUtc()
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toUtc()
          : null,
      conflictOf: json['conflictOf'] as String?,
      conflictField: json['conflictField'] as String?,
    );
  }
}

class PullResponse {
  final List<PulledNote> notes;
  final String? nextSince;

  const PullResponse({
    required this.notes,
    this.nextSince,
  });

  factory PullResponse.fromJson(Map<String, dynamic> json) {
    final rawNotes = (json['notes'] as List<dynamic>?) ?? [];
    return PullResponse(
      notes: rawNotes
          .map((n) => PulledNote.fromJson(n as Map<String, dynamic>))
          .toList(),
      nextSince: json['nextSince'] as String?,
    );
  }
}

abstract class SyncApi {
  Future<List<PushNoteResult>> push(List<Map<String, dynamic>> notes);
  Future<PullResponse> pull({String? since});
}

class HttpSyncApi implements SyncApi {
  final Dio _dio;

  HttpSyncApi(this._dio);

  @override
  Future<List<PushNoteResult>> push(List<Map<String, dynamic>> notes) async {
    if (notes.isEmpty) return const [];

    try {
      final response = await _dio.post('/sync/push', data: {'notes': notes});
      final data = _extractData(response);

      final list = data['results'] as List<dynamic>? ?? [];
      return list
          .map((item) => PushNoteResult.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      if (e is SyncFailure) rethrow;
      throw UnknownSyncFailure(e);
    }
  }

  @override
  Future<PullResponse> pull({String? since}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (since != null) {
        queryParams['since'] = since;
      }
      final response = await _dio.get('/sync/pull', queryParameters: queryParams);
      final data = _extractData(response);
      return PullResponse.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      if (e is SyncFailure) rethrow;
      throw UnknownSyncFailure(e);
    }
  }

  Map<String, dynamic> _extractData(Response response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      final inner = body['data'];
      if (inner is Map<String, dynamic>) return inner;
      return body;
    }
    return {};
  }

  SyncFailure _mapDioException(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.response == null) {
      return const NetworkUnavailableSyncFailure();
    }
    return ServerSyncFailure(
      statusCode: e.response?.statusCode,
      message: e.message,
    );
  }
}
