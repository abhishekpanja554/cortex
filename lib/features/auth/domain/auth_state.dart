import 'dart:convert';
import 'package:cortex/features/auth/data/token_storage.dart';

enum LogoutReason { userInitiated, sessionExpired }

sealed class AuthState {}

class Authenticated extends AuthState {
  final String userId;
  Authenticated(this.userId);
}

class Unauthenticated extends AuthState {
  final LogoutReason? reason;
  Unauthenticated(this.reason);
}

String decodeSub(String token) {
  final parts = token.split('.');
  if (parts.length != 3) throw Exception('Invalid token');
  
  final payload = parts[1];
  final normalized = base64Url.normalize(payload);
  final decoded = utf8.decode(base64Url.decode(normalized));
  final map = jsonDecode(decoded);
  return map['sub'];
}

AuthState initialAuthStateFrom(AuthTokens? tokens) {
  if (tokens == null) {
    return Unauthenticated(null);
  }
  try {
    final userId = decodeSub(tokens.accessToken);
    return Authenticated(userId);
  } catch (_) {
    return Unauthenticated(null);
  }
}
