import 'package:flutter/foundation.dart';
import 'package:flutter_telegram_miniapp/flutter_telegram_miniapp.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState extends ChangeNotifier {
  final ApiService _apiService;
  final AuthService _authService;

  AuthStatus _status = AuthStatus.initial;
  String? _token;
  int? _userId;
  String? _role;
  String? _errorMessage;
  bool _isReauthenticating = false;

  AuthState({required ApiService apiService, required AuthService authService})
    : _apiService = apiService,
      _authService = authService {
    _apiService.onUnauthorized = handleUnauthorized;
  }

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAdmin => _role == 'admin';
  String? get token => _token;
  int? get userId => _userId;
  String? get role => _role;
  String? get errorMessage => _errorMessage;

  /// Check storage for an existing, still-valid token first, otherwise
  /// authenticate fresh via Telegram initData.
  Future<void> initAuth() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // In production this is invisible to the user:
      // Telegram regenerates initData every time the mini app opens, so
      // this costs one quick network round trip, not a visible login screen.
      await authenticateWithTelegram();
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Authentication failed: $e';
      notifyListeners();
    }
  }

  /// Perform login using Telegram WebApp's raw initData string.
  Future<void> authenticateWithTelegram() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      // Read raw initData string (never initDataUnsafe -- only the raw
      // string can be HMAC-verified server-side; the parsed object is
      // client-side-only and not trustworthy on its own).
      String initData = '';
      try {
        initData = WebApp().initData;
      } catch (e) {
        debugPrint('WebApp.initData read error: $e');
      }

      if (initData.isEmpty) {
        // Genuinely means: this isn't running inside Telegram. In
        // production that's a real, user-facing state (someone opened
        // the URL directly in a browser) -- not a dev-mode fallback path.
        _status = AuthStatus.error;
        _errorMessage =
            'No Telegram session found. Please open this app inside Telegram.';
        notifyListeners();
        return;
      }

      final accessToken = await _apiService.authenticateTelegram(initData);
      _token = accessToken;
      _userId = _authService.getUserIdFromToken(accessToken);
      _role = _authService.getRoleFromToken(accessToken);
      await _authService.setToken(accessToken);
      _apiService.setAuthToken(accessToken);
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Called when a 401 is intercepted on any authenticated API call.
  ///
  /// Rather than immediately bouncing the user to a logged-out state,
  /// this attempts a silent recovery first: if the mini app is still
  /// open, WebApp().initData is still valid and a fresh token is one
  /// request away. A user mid-game shouldn't see a login screen just
  /// because their JWT happened to expire during the session.
  Future<void> handleUnauthorized() async {
    if (_isReauthenticating) return; // guards against duplicate concurrent
    // re-auth if several requests 401 at once
    _isReauthenticating = true;

    await _authService.clearToken();
    _token = null;
    _userId = null;
    _role = null;
    _apiService.clearAuthToken();

    await authenticateWithTelegram(); // already sets status/error internally either way
    _isReauthenticating = false;
  }

  /// Manual logout / reset
  Future<void> logout() async {
    await _authService.clearToken();
    _token = null;
    _userId = null;
    _role = null;
    _apiService.clearAuthToken();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
