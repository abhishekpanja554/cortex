import 'package:cortex/features/app_core/presentation/screens/app_base.dart';
import 'package:cortex/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AppBase(),
        routes: [
          GoRoute(
            path: 'notes',
            builder: (context, state) => const NotesListScreen(),
          ),
        ],
      ),
    ],
  );
});
