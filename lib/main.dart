import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/features/app_core/presentation/screens/splash_screen.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      builder: (context, child) {
        return LockScreen(child: child!);
      },
      home: const SplashScreen(),
    );
  }
}
