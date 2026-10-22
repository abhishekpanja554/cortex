import 'dart:convert';

import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Best-effort email of the signed-in user, read from the access token's
/// `email` claim (or `sub` when the backend uses the email as subject).
/// Null when it can't be determined — UI must handle that gracefully.
final currentUserEmailProvider = FutureProvider<String?>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth is! Authenticated) return null;

  final storage = ref.watch(tokenStorageProvider);
  final savedEmail = await storage.readEmail();
  if (savedEmail != null && savedEmail.isNotEmpty) {
    return savedEmail;
  }

  if (auth.userId.contains('@')) return auth.userId;

  final tokens = await storage.read();
  if (tokens == null) return null;
  return _emailFromJwt(tokens.accessToken);
});

String? _emailFromJwt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final map = jsonDecode(payload);
    if (map is! Map) return null;
    for (final key in const ['email', 'preferred_username', 'sub']) {
      final value = map[key];
      if (value is String && value.contains('@')) return value;
    }
  } catch (_) {}
  return null;
}
