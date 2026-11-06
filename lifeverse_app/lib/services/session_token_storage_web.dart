import 'dart:html' as html;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storageKey = 'lifeverse_session_token';
final _secureStorage = FlutterSecureStorage();

Future<void> saveToken(String sessionToken) async {
  await _secureStorage.write(key: _storageKey, value: sessionToken);
  html.window.localStorage.remove(_storageKey);
}

Future<String?> readToken() async {
  final token = await _secureStorage.read(key: _storageKey);
  if (token != null && token.trim().isNotEmpty) return token.trim();

  // Migrate existing browser sessions away from a plaintext localStorage entry.
  final legacyToken = html.window.localStorage[_storageKey]?.trim();
  if (legacyToken == null || legacyToken.isEmpty) return null;
  await _secureStorage.write(key: _storageKey, value: legacyToken);
  html.window.localStorage.remove(_storageKey);
  return legacyToken;
}

Future<void> clearToken() async {
  await _secureStorage.delete(key: _storageKey);
  html.window.localStorage.remove(_storageKey);
}
