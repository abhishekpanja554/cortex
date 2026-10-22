import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/auth/data/token_storage.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/auth/presentation/current_user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  group('currentUserEmailProvider & TokenStorage email persistence', () {
    late TokenStorage storage;
    final inMemoryStorage = <String, String>{};

    setUp(() {
      inMemoryStorage.clear();
      final mockSecure = MockFlutterSecureStorage();
      final mockPrefs = MockSharedPreferences();

      when(() => mockSecure.read(key: any(named: 'key')))
          .thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        return inMemoryStorage[key];
      });

      when(() => mockSecure.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        final value = invocation.namedArguments[#value] as String;
        inMemoryStorage[key] = value;
      });

      when(() => mockSecure.delete(key: any(named: 'key')))
          .thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        inMemoryStorage.remove(key);
      });

      storage = TokenStorage(mockSecure, mockPrefs);
    });

    test('writes and reads email accurately', () async {
      await storage.writeEmail('user@example.com');
      final email = await storage.readEmail();
      expect(email, 'user@example.com');

      await storage.clear();
      final cleared = await storage.readEmail();
      expect(cleared, isNull);
    });

    test('currentUserEmailProvider returns stored email for authenticated user', () async {
      await storage.writeEmail('saved@cortex.app');

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _TestAuthNotifier(
                Authenticated('55fee7bb-458f-4016-9d95-80115e7b2b49'),
              )),
          tokenStorageProvider.overrideWithValue(storage),
        ],
      );

      final email = await container.read(currentUserEmailProvider.future);
      expect(email, 'saved@cortex.app');
    });

    test('currentUserEmailProvider returns null when unauthenticated', () async {
      await storage.writeEmail('saved@cortex.app');

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _TestAuthNotifier(
                Unauthenticated(LogoutReason.userInitiated),
              )),
          tokenStorageProvider.overrideWithValue(storage),
        ],
      );

      final email = await container.read(currentUserEmailProvider.future);
      expect(email, isNull);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _TestAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}
