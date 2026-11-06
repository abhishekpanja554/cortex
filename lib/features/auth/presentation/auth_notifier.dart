import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';

final initialAuthStateProvider = Provider<AuthState>((ref) {
  throw UnimplementedError();
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return ref.read(initialAuthStateProvider);
  }

  Future<void> login(String email, String password) async {
    final authRepo = ref.read(authRepositoryProvider);
    final tokens = await authRepo.login(email, password);
    state = initialAuthStateFrom(tokens);
  }

  Future<void> register(String email, String password) async {
    final authRepo = ref.read(authRepositoryProvider);
    final tokens = await authRepo.register(email, password);
    state = initialAuthStateFrom(tokens);
  }

  Future<void>? _logoutFuture;

  Future<void> logout({LogoutReason reason = LogoutReason.userInitiated}) {
    if (state is Unauthenticated) return Future.value();
    return _logoutFuture ??= _doLogout(reason).whenComplete(() => _logoutFuture = null);
  }

  Future<void> _doLogout(LogoutReason reason) async {
    final authRepo = ref.read(authRepositoryProvider);
    final noteRepo = ref.read(noteRepositoryProvider);
    final securityService = ref.read(securityServiceProvider);
    
    await authRepo.logout();
    await noteRepo.wipeAll();
    await securityService.clearAll();
    
    state = Unauthenticated(reason);
  }

  Future<void> onSessionExpired() async {
    if (state is Unauthenticated) return;
    await logout(reason: LogoutReason.sessionExpired);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
