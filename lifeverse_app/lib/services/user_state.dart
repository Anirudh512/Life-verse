import 'package:flutter/foundation.dart';
import 'dart:async';
import 'api_service.dart';

class UserState extends ChangeNotifier {
  String? _userId;
  String? _sessionToken;
  String? _username;
  String? _fullName;
  Map<String, dynamic> _appState = {};
  bool _isRestoringSession = true;
  String? _sessionRestoreError;
  Timer? _appStateSaveTimer;
  Future<void> _appStateSaveQueue = Future<void>.value();

  String get userId => _userId ?? '';
  String? get sessionToken => _sessionToken;
  String get username => _username ?? '';
  String get fullName => _fullName ?? '';
  Map<String, dynamic> get appState => _appState;
  bool get isLoggedIn => _userId != null && _sessionToken != null;
  bool get isRestoringSession => _isRestoringSession;
  String? get sessionRestoreError => _sessionRestoreError;

  void setSession({
    required String userId,
    required String sessionToken,
    String? username,
    String? fullName,
    Map<String, dynamic>? appState,
  }) {
    _userId = userId;
    _sessionToken = sessionToken;
    _username = username;
    _fullName = fullName;
    if (appState != null) _appState = appState;
    _isRestoringSession = false;
    _sessionRestoreError = null;
    notifyListeners();
  }

  void updateAppState(Map<String, dynamic> state) {
    _appState = {..._appState, ...state};
    notifyListeners();
    _appStateSaveTimer?.cancel();
    if (isLoggedIn) {
      _appStateSaveTimer = Timer(
        const Duration(milliseconds: 350),
        _queueAppStateSave,
      );
    }
  }

  void updateIdentity({required String username, required String fullName}) {
    _username = username;
    _fullName = fullName;
    notifyListeners();
  }

  void _queueAppStateSave() {
    final userId = _userId;
    if (userId == null || userId.isEmpty || _sessionToken == null) return;
    final stateSnapshot = Map<String, dynamic>.from(_appState);
    _appStateSaveQueue = _appStateSaveQueue
        .then((_) async {
          if (_userId != userId || _sessionToken == null) return;
          final result = await ApiService.saveAppState(userId, stateSnapshot);
          if (result['success'] != true) {
            debugPrint(
              'LifeVerse preferences could not be saved: ${result['message'] ?? 'server unavailable'}',
            );
          }
        })
        .catchError((Object error) {
          debugPrint('LifeVerse preferences could not be saved: $error');
        });
  }

  void clearSession() {
    _appStateSaveTimer?.cancel();
    _userId = null;
    _sessionToken = null;
    _username = null;
    _fullName = null;
    _appState = {};
    _isRestoringSession = false;
    _sessionRestoreError = null;
    notifyListeners();
  }

  void setRestoringComplete() {
    _isRestoringSession = false;
    _sessionRestoreError = null;
    notifyListeners();
  }

  void beginSessionRestore() {
    _isRestoringSession = true;
    _sessionRestoreError = null;
    notifyListeners();
  }

  void setSessionRestoreError(String message) {
    _isRestoringSession = false;
    _sessionRestoreError = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _appStateSaveTimer?.cancel();
    super.dispose();
  }
}
