import 'package:cortex/features/app_core/presentation/screens/app_base.dart';
import 'package:cortex/features/app_core/presentation/screens/splash_screen.dart';
import 'package:cortex/features/notes/presentation/screens/edit_note_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/presentation/screens/login_screen.dart';
import 'package:cortex/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter/foundation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authStateNotifier = ValueNotifier<AuthState>(ref.read(authProvider));
  
  ref.listen(authProvider, (previous, next) {
    authStateNotifier.value = next;
  });

  ref.onDispose(() {
    authStateNotifier.dispose();
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authStateNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuth = authState is Authenticated;
      final isLoginRoute = state.uri.path == '/login';
      final isRegisterRoute = state.uri.path == '/register';

      if (!isAuth && !isLoginRoute && !isRegisterRoute) {
        return '/login';
      }
      if (isAuth && (isLoginRoute || isRegisterRoute)) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const AppBase(),
        routes: [
          GoRoute(
            path: 'edit-note',
            builder: (context, state) {
              final noteId = state.uri.queryParameters['id'];
              return EditNoteScreen(noteId: noteId);
            },
          ),
        ],
      ),
    ],
  );
});
