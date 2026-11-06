import 'session_token_storage_io.dart'
    if (dart.library.html) 'session_token_storage_web.dart' as storage;

/// Stores only the session token in platform secure storage.
/// Existing plaintext file/localStorage tokens are migrated on first read.
class SessionTokenCache {
  static Future<void> save(String sessionToken) => storage.saveToken(sessionToken);

  static Future<String?> read() => storage.readToken();

  static Future<void> clear() => storage.clearToken();
}
