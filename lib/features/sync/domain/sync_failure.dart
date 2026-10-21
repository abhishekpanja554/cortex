sealed class SyncFailure implements Exception {
  const SyncFailure();
}

class NetworkUnavailableSyncFailure extends SyncFailure {
  const NetworkUnavailableSyncFailure();

  @override
  String toString() => 'SyncFailure: network unavailable';
}

class ServerSyncFailure extends SyncFailure {
  final int? statusCode;
  final String? message;

  const ServerSyncFailure({this.statusCode, this.message});

  @override
  String toString() =>
      'SyncFailure: server error (status=$statusCode, message=$message)';
}

class SessionExpiredSyncFailure extends SyncFailure {
  const SessionExpiredSyncFailure();

  @override
  String toString() => 'SyncFailure: session expired or logged out';
}

class UnknownSyncFailure extends SyncFailure {
  final Object error;

  const UnknownSyncFailure(this.error);

  @override
  String toString() => 'SyncFailure: unknown ($error)';
}
