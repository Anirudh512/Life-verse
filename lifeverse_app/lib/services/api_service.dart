import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiService {
  static String? _sessionToken;

  static String get baseUrl => AppConfig.apiBaseUrl;

  static Uri _uri(String path) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final requestPath = '$base$path';
    if (kIsWeb && base.startsWith('/')) {
      return Uri.base.resolve(requestPath);
    }
    return Uri.parse(requestPath);
  }

  static void setSessionToken(String? token) {
    _sessionToken = token;
  }

  static Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (_sessionToken != null && _sessionToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    }
    return headers;
  }

  static Map<String, dynamic> _parseBody(http.Response response) {
    if (response.body.isEmpty) {
      return {
        'success': false,
        'httpStatus': response.statusCode,
        'message':
            'Empty response from server (HTTP ${response.statusCode}). Is the backend running?',
      };
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['success'] != true && response.statusCode >= 400) {
          return {
            'success': false,
            'httpStatus': response.statusCode,
            'message':
                decoded['message'] ??
                decoded['error'] ??
                'Request failed (${response.statusCode})',
          };
        }
        return {...decoded, 'httpStatus': response.statusCode};
      }
      return {
        'success': false,
        'httpStatus': response.statusCode,
        'message': 'Unexpected server response format.',
      };
    } catch (_) {
      return {
        'success': false,
        'httpStatus': response.statusCode,
        'message':
            'Server returned invalid data. Start backend: cd lifeverse_backend && npm start',
      };
    }
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await http
          .get(_uri(path), headers: _headers(json: false))
          .timeout(const Duration(seconds: 15));
      return _parseBody(response);
    } on TimeoutException {
      return {
        'success': false,
        'networkError': true,
        'message': 'Connection timed out. Check that the backend is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'networkError': true,
        'message':
            'Cannot connect to server at $baseUrl. Run: npm start in lifeverse_backend folder.',
      };
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            _uri(path),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _parseBody(response);
    } on TimeoutException {
      return {
        'success': false,
        'networkError': true,
        'message': 'Connection timed out. Check that the backend is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'networkError': true,
        'message':
            'Cannot connect to server at $baseUrl. Run: npm start in lifeverse_backend folder.',
      };
    }
  }

  static Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .put(
            _uri(path),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _parseBody(response);
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timed out.'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to server at $baseUrl.',
      };
    }
  }

  static Future<Map<String, dynamic>> _delete(String path) async {
    try {
      final response = await http
          .delete(_uri(path), headers: _headers(json: false))
          .timeout(const Duration(seconds: 15));
      return _parseBody(response);
    } on TimeoutException {
      return {
        'success': false,
        'networkError': true,
        'message': 'Connection timed out. Check that the backend is running.',
      };
    } catch (_) {
      return {
        'success': false,
        'networkError': true,
        'message':
            'Cannot connect to server at $baseUrl. Run: npm start in lifeverse_backend folder.',
      };
    }
  }

  static Future<Map<String, dynamic>> register(
    String fullName,
    String email,
    String username,
    String password,
    String securityQuestion,
    String securityAnswer,
  ) async {
    return _post('/auth/register', {
      'fullName': fullName,
      'email': email,
      'username': username,
      'password': password,
      'securityQuestion': securityQuestion,
      'securityAnswer': securityAnswer,
    });
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final data = await _post('/auth/login', {
      'email': email,
      'password': password,
      'deviceInfo': {'platform': 'flutter'},
    });
    if (data['success'] == true && data['sessionToken'] != null) {
      setSessionToken(data['sessionToken'] as String);
    }
    return data;
  }

  static Future<Map<String, dynamic>> validateSession(
    String sessionToken,
  ) async {
    setSessionToken(sessionToken);
    return _get('/auth/session/validate');
  }

  static Future<Map<String, dynamic>> logout() async {
    final data = await _post('/auth/logout', {});
    setSessionToken(null);
    return data;
  }

  static Future<Map<String, dynamic>> deleteAccount(
    String userId,
    String password,
  ) async {
    final data = await _post('/auth/account/delete', {
      'userId': userId,
      'password': password,
    });
    if (data['success'] == true) setSessionToken(null);
    return data;
  }

  static Future<Map<String, dynamic>> saveAppState(
    String userId,
    Map<String, dynamic> state,
  ) async {
    return _put('/auth/app-state/$userId', {'state': state});
  }

  static Future<Map<String, dynamic>> recoverPassword(
    String email,
    String username,
    String securityAnswer,
    String newPassword,
  ) async {
    return _post('/auth/recover', {
      'email': email,
      'username': username,
      'securityAnswer': securityAnswer,
      'newPassword': newPassword,
    });
  }

  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final data = await _get('/auth/profile/$userId');
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Profile fetch failed');
    }
    return data;
  }

  static Future<Map<String, dynamic>> updateUserProfile(
    String userId, {
    required String fullName,
    required String username,
  }) => _put('/auth/profile/${Uri.encodeComponent(userId)}', {
    'fullName': fullName,
    'username': username,
  });

  static Future<Map<String, dynamic>> createTimeCapsule(
    String userId,
    String message,
    String unlockDate,
  ) async {
    return _post('/capsules', {
      'userId': userId,
      'message': message,
      'openDate': unlockDate,
      'title': 'A Memory Preserved',
    });
  }

  static Future<Map<String, dynamic>> logMicroDecision(
    String userId,
    String decisionText, {
    List<String>? tags,
  }) async {
    try {
      final res = await http
          .post(
        _uri('/butterfly/log'),
            headers: _headers(),
            body: jsonEncode({
              'userId': userId,
              'decisionText': decisionText,
              'contextTags': tags,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _parseBody(res);
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Connection timed out. Check that the backend is running.',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getButterflyAnalysis(
    String userId,
  ) async {
    try {
      final res = await http
          .get(
        _uri('/butterfly/analysis/$userId'),
            headers: _headers(json: false),
          )
          .timeout(const Duration(seconds: 15));
      return _parseBody(res);
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Connection timed out. Check that the backend is running.',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createCapsuleWithMedia({
    required String userId,
    required String idempotencyKey,
    required String title,
    required String message,
    required String openDate,
    String? prediction,
    String themeStyle = 'amber_gold',
    String capsuleType = 'self',
    String? recipientUsername,
    Map<String, dynamic> capsuleData = const {},
    List<dynamic> mediaFiles = const [],
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _uri('/capsules/create'),
      );
      if (_sessionToken != null && _sessionToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_sessionToken';
      }
      request.headers['Idempotency-Key'] = idempotencyKey;

      request.fields['userId'] = userId;
      request.fields['title'] = title;
      request.fields['message'] = message;
      request.fields['openDate'] = openDate;
      request.fields['themeStyle'] = themeStyle;
      request.fields['capsuleType'] = capsuleType;
      if (prediction != null && prediction.isNotEmpty) {
        request.fields['prediction'] = prediction;
      }
      if (recipientUsername != null && recipientUsername.isNotEmpty) {
        request.fields['recipientUsername'] = recipientUsername;
      }

      // Pass coordinates if they exist
      if (capsuleData.containsKey('latitude') &&
          capsuleData['latitude'] != null) {
        request.fields['latitude'] = capsuleData['latitude'].toString();
        request.fields['longitude'] = capsuleData['longitude'].toString();
      }

      // Pass contributors if they exist
      if (capsuleData.containsKey('contributors') &&
          capsuleData['contributors'] != null) {
        request.fields['contributors'] = jsonEncode(
          capsuleData['contributors'],
        );
      }

      for (final item in mediaFiles) {
        PlatformFile file;
        String fileName;
        if (item is PlatformFile) {
          file = item;
          fileName = item.name;
        } else {
          file = item.file as PlatformFile;
          fileName = item.customName as String;
          if (!fileName.contains('.')) {
            final ext = file.extension ?? file.name.split('.').last;
            if (ext.isNotEmpty) {
              fileName = '$fileName.$ext';
            }
          }
        }

        if (file.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'media',
              file.bytes!,
              filename: fileName,
            ),
          );
        } else if (file.path != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'media',
              file.path!,
              filename: fileName,
            ),
          );
        }
      }

      final streamed = await request.send().timeout(const Duration(minutes: 5));
      final response = await http.Response.fromStream(streamed);
      return _parseBody(response);
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Upload timed out. Try fewer or smaller files.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to upload capsule: $e'};
    }
  }

  static Future<Map<String, dynamic>> lookupCapsuleFriend(
    String username,
  ) async {
    return _get('/capsules/lookup/${Uri.encodeComponent(username.trim())}');
  }

  static Future<Map<String, dynamic>> getAllCapsules(String userId) async {
    return _get('/capsules/$userId');
  }

  static Future<Map<String, dynamic>> getPendingCapsuleDeliveries(
    String userId,
  ) async {
    return _get('/capsules/pending/$userId');
  }

  static Future<Map<String, dynamic>> getCapsuleDetail(
    String capsuleId,
    String userId,
  ) async {
    return _get('/capsules/detail/$capsuleId/$userId');
  }

  static Future<Map<String, dynamic>> checkCapsuleStatus(String userId) async {
    return _get('/capsules/status/$userId');
  }

  static Future<Map<String, dynamic>> openCapsule(
    String userId,
    String capsuleId, {
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{'userId': userId, 'capsuleId': capsuleId};
    if (latitude != null && longitude != null) {
      body['latitude'] = latitude;
      body['longitude'] = longitude;
    }
    return _post('/capsules/open', body);
  }

  static Future<Map<String, dynamic>> markCapsuleDelivered(
    String capsuleId,
  ) async {
    return _post('/capsules/delivered', {'capsuleId': capsuleId});
  }

  static String mediaUrl(String path) {
    if (path.isEmpty) return path;
    return path.startsWith('http') ? path : '${AppConfig.serverBaseUrl}$path';
  }

  static Map<String, String> mediaHeadersFor(String path) {
    final mediaUri = Uri.tryParse(mediaUrl(path));
    final serverBaseUrl = AppConfig.serverBaseUrl;
    final apiUri = serverBaseUrl.isEmpty && kIsWeb
        ? Uri.base
        : Uri.tryParse(serverBaseUrl);
    final resolvedMediaUri = mediaUri == null
        ? null
        : (mediaUri.hasScheme || !kIsWeb
              ? mediaUri
              : Uri.base.resolveUri(mediaUri));
    if (resolvedMediaUri == null ||
        apiUri == null ||
        resolvedMediaUri.origin != apiUri.origin) {
      return const {};
    }
    return _headers(json: false);
  }

  static Future<Map<String, dynamic>> generateHDETasks(
    String userId,
    String dimension,
  ) async {
    final data = await _post('/hde/tasks', {
      'userId': userId,
      'dimension': dimension,
    });
    if (data['success'] != true) {
      throw Exception(
        data['message'] ?? data['error'] ?? 'Failed to generate tasks',
      );
    }
    return data;
  }

  static Future<Map<String, dynamic>> getHdeStats(String userId) async {
    return _get('/hde/stats/$userId');
  }

  static Future<Map<String, dynamic>> completeDailyTask(
    String userId,
    String dimension,
    String taskTitle,
  ) async {
    final data = await _post('/hde/tasks/complete', {
      'userId': userId,
      'dimension': dimension,
      'taskTitle': taskTitle,
    });
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to complete task');
    }
    return data;
  }

  static Future<Map<String, dynamic>> submitDailySurvey(
    String userId,
    String dimension,
    List<Map<String, String>> surveyData,
  ) async {
    final data = await _post('/hde/survey/submit', {
      'userId': userId,
      'dimension': dimension,
      'surveyData': surveyData,
    });
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to submit survey');
    }
    return data;
  }

  static Future<Map<String, dynamic>> getXPAnalytics(String userId) async {
    final data = await _get('/analytics/xp/$userId');
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Analytics fetch failed');
    }
    return data;
  }

  static Future<Map<String, dynamic>> getProgressAnalytics(
    String userId, {
    int days = 7,
  }) => _get('/analytics/progress/${Uri.encodeComponent(userId)}?days=$days');

  static Future<Map<String, dynamic>> recordAppVisit() =>
      _post('/analytics/visit', const {});

  static Future<Map<String, dynamic>> getGrowthGoals(String userId) =>
      _get('/growth-goals/${Uri.encodeComponent(userId)}');

  static Future<Map<String, dynamic>> createGrowthGoal({
    required String userId,
    required String title,
    required String dimension,
    required int targetTasks,
    required String dueDate,
    required bool reminderEnabled,
    required String progressMetric,
  }) => _post('/growth-goals', {
    'userId': userId,
    'title': title,
    'dimension': dimension,
    'targetTasks': targetTasks,
    'dueDate': dueDate,
    'reminderEnabled': reminderEnabled,
    'progressMetric': progressMetric,
  });

  static Future<Map<String, dynamic>> updateGrowthGoal({
    required String userId,
    required String goalId,
    required String title,
    required String dimension,
    required int targetTasks,
    required String dueDate,
    required bool reminderEnabled,
    required String progressMetric,
  }) => _put(
    '/growth-goals/${Uri.encodeComponent(userId)}/${Uri.encodeComponent(goalId)}',
    {
      'userId': userId,
      'title': title,
      'dimension': dimension,
      'targetTasks': targetTasks,
      'dueDate': dueDate,
      'reminderEnabled': reminderEnabled,
      'progressMetric': progressMetric,
    },
  );

  static Future<Map<String, dynamic>> deleteGrowthGoal(
    String userId,
    String goalId,
  ) => _delete(
    '/growth-goals/${Uri.encodeComponent(userId)}/${Uri.encodeComponent(goalId)}',
  );

  static Future<Map<String, dynamic>> getTwinProfile(String userId) async {
    return _get('/twin/profile/$userId');
  }

  static Future<Map<String, dynamic>> getLegacyTimeline(String userId) async {
    return _get('/legacy/timeline/$userId');
  }

  static Future<Map<String, dynamic>> generateAIBiography(
    String userId, {
    bool save = false,
    bool includeReflections = true,
  }) async {
    return _post('/legacy/biography', {
      'userId': userId,
      'save': save,
      'includeReflections': includeReflections,
    });
  }

  static Future<Map<String, dynamic>> saveAIBiography(
    String userId,
    String biography,
  ) async {
    return _put('/legacy/biography', {
      'userId': userId,
      'biography': biography,
    });
  }

  static Future<Map<String, dynamic>> addLegacyEvent(
    String userId, {
    required String title,
    required String description,
    required String chapter,
    List<String> coreValues = const [],
  }) async {
    return _post('/legacy/event', {
      'userId': userId,
      'eventData': {
        'title': title,
        'description': description,
        'chapter': chapter,
        'type': 'MILESTONE',
        'coreValues': coreValues,
      },
    });
  }

  static Future<Map<String, dynamic>> getFutureUnlockStatus(
    String userId,
  ) async {
    return _get('/future/status/$userId');
  }

  static Future<Map<String, dynamic>> simulateFuture(
    String userId, {
    String? decisionQuestion,
  }) async {
    return _post('/future/simulate', {
      'userId': userId,
      'decisionQuestion': decisionQuestion,
    });
  }

  static Future<Map<String, dynamic>> getLatestSimulation(String userId) async {
    return _get('/future/latest/$userId');
  }

  static Future<Map<String, dynamic>> saveSimulationFeedback(
    String userId, {
    required String simulationId,
    required bool helpful,
  }) async {
    return _post('/future/feedback', {
      'userId': userId,
      'simulationId': simulationId,
      'helpful': helpful,
    });
  }

  static Future<Map<String, dynamic>> commitSimulationRecommendation(
    String userId, {
    required String title,
    String? description,
    String? dimension,
  }) async {
    return _post('/future/commit', {
      'userId': userId,
      'title': title,
      'description': description,
      'dimension': dimension,
    });
  }

  static Future<Map<String, dynamic>> generateMirrorQuestion(
    String userId,
  ) async {
    return _post('/twin/mirror', {'userId': userId});
  }

  static Future<Map<String, dynamic>> getTwinConversationHistory(
    String userId,
    String persona, {
    String? beforeId,
  }) async {
    final cursor = beforeId == null
        ? ''
        : '&beforeId=${Uri.encodeQueryComponent(beforeId)}';
    return _get(
      '/twin/history/${Uri.encodeComponent(userId)}?persona=${Uri.encodeQueryComponent(persona)}$cursor',
    );
  }

  static Future<Map<String, dynamic>> getTwinMemories(String userId) async {
    return _get('/twin/memories/${Uri.encodeComponent(userId)}');
  }

  static Future<Map<String, dynamic>> deleteTwinMemory(
    String userId,
    int memoryId,
  ) async {
    return _delete('/twin/memories/${Uri.encodeComponent(userId)}/$memoryId');
  }

  static Future<Map<String, dynamic>> clearTwinConversationHistory(
    String userId,
  ) async {
    return _delete('/twin/history/${Uri.encodeComponent(userId)}');
  }

  static Future<Map<String, dynamic>> chatWithTwin(
    String userId,
    String userMessage,
    String persona, {
    bool includeLifeVerseContext = false,
  }) async {
    return _post('/twin/chat_twin', {
      'userId': userId,
      'userMessage': userMessage,
      'persona': persona,
      'includeLifeVerseContext': includeLifeVerseContext,
    });
  }

  // Social Methods
  static Future<Map<String, dynamic>> sendFriendRequest(
    String senderId,
    String receiverUsername,
  ) async {
    return _post('/friends/request', {
      'senderId': senderId,
      'receiverUsername': receiverUsername,
    });
  }

  static Future<Map<String, dynamic>> acceptFriendRequest(
    String senderId,
    String receiverId,
  ) async {
    return _post('/friends/accept', {
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }

  static Future<Map<String, dynamic>> getFriendsList(String userId) async {
    return _get('/friends/list/$userId');
  }

  static Future<Map<String, dynamic>> getFriendProfile(String friendId) async {
    return _get('/friends/profile/${Uri.encodeComponent(friendId)}');
  }
}
