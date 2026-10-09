import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/core/database/app_database_provider.dart';
import 'package:cortex/core/database/database_key_store.dart';
import 'package:cortex/core/navigation/router.dart';
import 'package:cortex/features/security/presentation/screens/lock_screen.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const secureStorage = FlutterSecureStorage();
  final keyStore = DatabaseKeyStore(secureStorage);
  final hexKey = await keyStore.getOrCreateKey();
  final appDatabase = AppDatabase(openEncryptedConnection(hexKey));

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appTitle,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.searchBarBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.searchBarBackground,
        ),
      ),
      routerConfig: router,
      builder: (context, child) {
        return LockScreen(child: child!);
      },
    );
  }
}
