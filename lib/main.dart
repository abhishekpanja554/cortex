import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/navigation/router.dart';
import 'package:cortex/features/security/presentation/screens/lock_screen.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cortex/core/database/isar_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isar = await IsarDatabase.init();

  runApp(
    ProviderScope(
      overrides: [isarProvider.overrideWithValue(isar)],
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.searchBarBackground),
      ),
      routerConfig: router,
      builder: (context, child) {
        return LockScreen(child: child!);
      },
    );
  }
}
