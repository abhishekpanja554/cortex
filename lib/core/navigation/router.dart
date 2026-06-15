import 'package:cortex/features/app_core/presentation/screens/app_base.dart';
import 'package:cortex/features/app_core/presentation/screens/splash_screen.dart';
import 'package:cortex/features/notes/presentation/screens/edit_note_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
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
