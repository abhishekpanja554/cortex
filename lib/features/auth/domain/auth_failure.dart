sealed class AuthFailure implements Exception {}

class InvalidCredentials extends AuthFailure {}

class EmailAlreadyInUse extends AuthFailure {}

class ValidationFailed extends AuthFailure {
  final String message;
  ValidationFailed(this.message);
}

class SessionExpired extends AuthFailure {}

class NetworkUnavailable extends AuthFailure {}

class ServerError extends AuthFailure {
  final int? status;
  final String? requestId;
  ServerError(this.status, this.requestId);
}
