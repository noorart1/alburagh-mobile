import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted-at-rest storage for the access/refresh token pair (Keychain on
/// iOS, EncryptedSharedPreferences/Keystore on Android). Unlike the rest of
/// the app's session data (user id/email/name, still in SharedPreferences),
/// tokens must never land in plaintext local storage.
class SecureTokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  static Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  static Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
