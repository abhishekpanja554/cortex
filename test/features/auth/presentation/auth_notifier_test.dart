import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/domain/auth_failure.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/auth/data/auth_repository.dart';
import 'package:cortex/features/notes/data/repositories/drift_note_repository.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:drift/native.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/auth/data/token_storage.dart';
import 'dart:io';
import 'package:cortex/features/security/services/security_service.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockSecurityService extends Mock implements SecurityService {}

void main() {
  group('AuthNotifier', () {
    late MockAuthRepository authRepo;
    late MockSecurityService securityService;
    late AppDatabase memoryDb;
    late DriftNoteRepository noteRepo;
    late Directory tempDir;
    
    setUp(() {
      authRepo = MockAuthRepository();
      securityService = MockSecurityService();
      memoryDb = AppDatabase(NativeDatabase.memory());
      tempDir = Directory.systemTemp.createTempSync('cortex_test_docs');
      noteRepo = DriftNoteRepository(memoryDb, tempDir);
    });
    
    tearDown(() async {
      await memoryDb.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    ProviderContainer makeContainer({required AuthState initialState}) {
      final container = ProviderContainer(
        overrides: [
          initialAuthStateProvider.overrideWithValue(initialState),
          authRepositoryProvider.overrideWithValue(authRepo),
          noteRepositoryProvider.overrideWithValue(noteRepo),
          securityServiceProvider.overrideWithValue(securityService),
        ],
      );
      return container;
    }

    test('1 initialAuthStateFrom with tokens -> Authenticated, userId = JWT sub', () {
      final token = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI1NWZlZTdiYi00NThmLTQwMTYtOWQ5NS04MDExNWU3YjJiNDkiLCJpYXQiOjE3OTE1NzEwNjYsImV4cCI6MTc5MTU3MTA4Nn0.qN6JB3kmw7mwmqTtvR4QBSblMkmhmDcvg98wdYlmQMw';
      
      final state = initialAuthStateFrom(AuthTokens(accessToken: token, refreshToken: 'ref'));
      
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).userId, '55fee7bb-458f-4016-9d95-80115e7b2b49');
    });

    test('1b initialAuthStateFrom with malformed access token -> Unauthenticated(null)', () {
      final state = initialAuthStateFrom(AuthTokens(accessToken: 'garbage', refreshToken: 'ref'));
      expect(state, isA<Unauthenticated>());
      expect((state as Unauthenticated).reason, isNull);
    });

    test('2 initialAuthStateFrom without tokens -> Unauthenticated(null)', () {
      final state = initialAuthStateFrom(null);
      
      expect(state, isA<Unauthenticated>());
      expect((state as Unauthenticated).reason, isNull);
    });

    test('3 login success -> Authenticated with specific userId', () async {
      final container = makeContainer(initialState: Unauthenticated(null));
      
      final token = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI1NWZlZTdiYi00NThmLTQwMTYtOWQ5NS04MDExNWU3YjJiNDkiLCJpYXQiOjE3OTE1NzEwNjYsImV4cCI6MTc5MTU3MTA4Nn0.qN6JB3kmw7mwmqTtvR4QBSblMkmhmDcvg98wdYlmQMw';
      final authTokens = AuthTokens(accessToken: token, refreshToken: 'ref');
      
      when(() => authRepo.login('test', 'password')).thenAnswer((_) async => authTokens);
      
      await container.read(authProvider.notifier).login('test', 'password');
      
      final stateAfterLogin = container.read(authProvider);
      expect(stateAfterLogin, isA<Authenticated>());
      expect((stateAfterLogin as Authenticated).userId, '55fee7bb-458f-4016-9d95-80115e7b2b49');
    });

    test('3b login throws InvalidCredentials -> rethrown, state unchanged (Unauthenticated)', () async {
      final container = makeContainer(initialState: Unauthenticated(null));
      
      when(() => authRepo.login('fail', 'password')).thenThrow(InvalidCredentials());
      
      await expectLater(
        () => container.read(authProvider.notifier).login('fail', 'password'), 
        throwsA(isA<InvalidCredentials>())
      );
      
      final stateAfterFail = container.read(authProvider);
      expect(stateAfterFail, isA<Unauthenticated>());
      expect((stateAfterFail as Unauthenticated).reason, isNull);
    });

    test('4 logout -> repository logout called, notes table empty, Unauthenticated(userInitiated)', () async {
      final container = makeContainer(initialState: Authenticated('user-123'));
      
      // Save two notes
      await noteRepo.saveNote(NoteEntity(id: 'note-1', title: '', body: '', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await noteRepo.saveNote(NoteEntity(id: 'note-2', title: '', body: '', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      
      // Write an attachment file
      final attachmentDir = Directory('${tempDir.path}/attachments');
      attachmentDir.createSync(recursive: true);
      final file = File('${attachmentDir.path}/x.jpg');
      file.writeAsStringSync('dummy data');
      expect(file.existsSync(), isTrue);

      when(() => authRepo.logout()).thenAnswer((_) async {});
      when(() => securityService.clearAll()).thenAnswer((_) async {});
      
      await container.read(authProvider.notifier).logout();
      
      verify(() => authRepo.logout()).called(1);
      verify(() => securityService.clearAll()).called(1);
      
      final notesCount = await memoryDb.select(memoryDb.notes).get();
      expect(notesCount.length, 0);
      
      expect(attachmentDir.existsSync(), isFalse);
      
      final state = container.read(authProvider);
      expect(state, isA<Unauthenticated>());
      expect((state as Unauthenticated).reason, LogoutReason.userInitiated);
    });

    test('5 onSessionExpired() called 3 times -> repository logout called exactly once, state Unauthenticated(sessionExpired)', () async {
      final container = makeContainer(initialState: Authenticated('user-123'));
      
      // Setup mocked logout with async delay to ensure idempotency check works across awaits
      when(() => authRepo.logout()).thenAnswer((_) async => await Future.delayed(const Duration(milliseconds: 100)));
      when(() => securityService.clearAll()).thenAnswer((_) async {});
      
      final futures = [
        container.read(authProvider.notifier).onSessionExpired(),
        container.read(authProvider.notifier).onSessionExpired(),
        container.read(authProvider.notifier).onSessionExpired(),
      ];
      await Future.wait(futures);
      
      verify(() => authRepo.logout()).called(1);
      verify(() => securityService.clearAll()).called(1);
      final state = container.read(authProvider);
      expect(state, isA<Unauthenticated>());
      expect((state as Unauthenticated).reason, LogoutReason.sessionExpired);
    });
  });
}
