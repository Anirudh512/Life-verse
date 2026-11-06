import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

const _fileName = 'lifeverse_session.token';
const _storageKey = 'lifeverse_session_token';
final _secureStorage = FlutterSecureStorage();

Future<File> _legacyTokenFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$_fileName');
}

Future<void> saveToken(String sessionToken) async {
  await _secureStorage.write(key: _storageKey, value: sessionToken);
  final legacyFile = await _legacyTokenFile();
  if (await legacyFile.exists()) await legacyFile.delete();
}

Future<String?> readToken() async {
  final token = await _secureStorage.read(key: _storageKey);
  if (token != null && token.trim().isNotEmpty) return token.trim();

  // Migrate existing installations without making users sign in again.
  final legacyFile = await _legacyTokenFile();
  if (!await legacyFile.exists()) return null;
  final legacyToken = (await legacyFile.readAsString()).trim();
  if (legacyToken.isEmpty) return null;
  await _secureStorage.write(key: _storageKey, value: legacyToken);
  await legacyFile.delete();
  return legacyToken;
}

Future<void> clearToken() async {
  await _secureStorage.delete(key: _storageKey);
  final legacyFile = await _legacyTokenFile();
  if (await legacyFile.exists()) await legacyFile.delete();
}
