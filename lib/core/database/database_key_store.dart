import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DatabaseKeyStore {
  final FlutterSecureStorage _storage;
  static const String _storageKey = 'database_encryption_key';

  DatabaseKeyStore(this._storage);

  Future<String> getOrCreateKey() async {
    final existingKey = await _storage.read(key: _storageKey);
    if (existingKey != null) {
      return existingKey;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final newKey = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('');
    await _storage.write(key: _storageKey, value: newKey);
    return newKey;
  }
}
