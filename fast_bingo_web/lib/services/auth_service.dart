import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages JWT token persistence and lightweight payload extraction.
class AuthService {
  static const _tokenKey = 'fast_bingo_jwt';
  final FlutterSecureStorage _storage;

  AuthService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Retrieve a previously stored JWT, or null if none exists.
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Persist a JWT for next app launch.
  Future<void> setToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Clear the stored JWT (e.g. on 401 / forced re-auth).
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Extract the user id (`sub` claim) from a JWT without verification.
  /// The server handles real verification — this is purely so the client
  /// can compare winner_user_id against the logged-in user.
  int? getUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // JWT payload is base64url-encoded
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final sub = map['sub'];
      if (sub is int) return sub;
      if (sub is String) return int.tryParse(sub);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extract the user role (`role` claim, e.g. "admin" or "user") from a JWT.
  String? getRoleFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return map['role'] as String?;
    } catch (_) {
      return null;
    }
  }
}
