import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/core/database/app_database_provider.dart';
import 'package:cortex/core/database/database_key_store.dart';
import 'package:cortex/core/navigation/router.dart';
import 'package:cortex/core/theme/app_theme.dart';
import 'package:cortex/features/security/presentation/screens/lock_screen.dart';
import 'package:cortex/features/sync/presentation/sync_orchestrator.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/data/token_storage.dart';
import 'package:cortex/core/providers/core_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  
  final prefs = await SharedPreferences.getInstance();
  final tokenStorage = TokenStorage(secureStorage, prefs);
  
  await tokenStorage.wipeIfFirstRun();

  final keyStore = DatabaseKeyStore(secureStorage);
  final hexKey = await keyStore.getOrCreateKey();
  final appDatabase = AppDatabase(openEncryptedConnection(hexKey));
  final docsDir = await getApplicationDocumentsDirectory();

  final initialTokens = await tokenStorage.read();
  final initialState = initialAuthStateFrom(initialTokens);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(appDatabase),
        secureStorageProvider.overrideWithValue(secureStorage),
        tokenStorageProvider.overrideWithValue(tokenStorage),
        documentsDirectoryProvider.overrideWithValue(docsDir),
        initialAuthStateProvider.overrideWithValue(initialState),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return SyncOrchestrator(
      child: MaterialApp.router(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        scrollBehavior: AppTheme.scrollBehavior,
        routerConfig: router,
        builder: (context, child) {
          final authState = ref.watch(authProvider);
          if (authState is Authenticated) {
            return LockScreen(child: child!);
          }
          return child!;
        },
      ),
    );
  }
}

