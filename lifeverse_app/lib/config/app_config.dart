import 'package:flutter/foundation.dart';

/// API base URL configuration.
/// - Local development: Web / Windows / iOS simulator / macOS / Linux → localhost
/// - Local Android emulator → 10.0.2.2
/// - Combined Flutter Web + API release → --dart-define=API_BASE_URL=/api
/// - Native release → --dart-define=API_BASE_URL=https://your-app.onrender.com/api
class AppConfig {
  static const String productionApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (productionApiUrl.trim().isNotEmpty) {
      final configured = productionApiUrl.trim();
      if (configured.startsWith('/') && !kIsWeb) {
        throw StateError(
          'Relative API_BASE_URL values are supported only for Flutter Web.',
        );
      }
      return configured;
    }
    if (kReleaseMode) {
      throw StateError('Release builds must set --dart-define=API_BASE_URL=https://your-api-host/api');
    }
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000/api';
      default:
        // Windows, iOS, macOS, Linux
        return 'http://localhost:3000/api';
    }
  }

  /// Base URL for uploaded media (no trailing /api suffix).
  static String get serverBaseUrl {
    final normalized = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    return normalized.endsWith('/api')
        ? normalized.substring(0, normalized.length - 4)
        : normalized;
  }
}
