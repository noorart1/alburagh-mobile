import 'dart:async';

import 'package:dio/dio.dart';
import 'secure_token_storage.dart';

/// Attaches the access token to outgoing requests and, on a 401, transparently
/// refreshes the session and retries the request once -- so an expired access
/// token never surfaces as a failed request or a forced logout by itself.
///
/// Only registered on the primary `_dio` client (see ApiService) -- the
/// `_wpDio` client is only ever used for the unauthenticated JWT-plugin
/// login fallback, nothing on it needs a Bearer header or a refresh.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.refreshTokens,
    required this.onSessionExpired,
  });

  /// The Dio instance to retry requests on after a refresh. Must be the same
  /// instance this interceptor is attached to.
  final Dio dio;

  /// Exchanges a refresh token for a new {access, refresh} pair. Throws
  /// [DioException] on failure -- a response-bearing exception (401/403)
  /// means the refresh token is genuinely dead; a response-less one (timeout,
  /// connection error) means it's just offline.
  final Future<Map<String, String>> Function(String refreshToken) refreshTokens;

  /// Called when the session is definitively over (refresh token missing,
  /// expired, or rejected by the server) -- never for a plain network error.
  final void Function() onSessionExpired;

  // Requests to these endpoints never get a Bearer header attached, and a
  // 401 from them never triggers a refresh attempt -- refreshing on a failed
  // login/register call makes no sense, and refreshing on a failed
  // refresh-token call would loop forever.
  static const _excludedPaths = {
    'login',
    'register',
    'forgot-password',
    'refresh-token',
  };

  // Null when no refresh is in flight. Because Dart never preempts between
  // await points, every synchronous statement before the first `await` in
  // _refreshAccessToken runs atomically -- so concurrent 401s all observe
  // the same completer instead of racing to create their own.
  Completer<String?>? _refreshCompleter;

  bool _isExcluded(String path) =>
      _excludedPaths.any((excluded) => path == excluded || path.endsWith('/$excluded'));

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_isExcluded(options.path) || options.headers.containsKey('Authorization')) {
      handler.next(options);
      return;
    }

    final accessToken = await SecureTokenStorage.readAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final status = err.response?.statusCode;

    final alreadyRetried = options.extra['authRetried'] == true;
    if (status != 401 || _isExcluded(options.path) || alreadyRetried) {
      handler.next(err);
      return;
    }

    final refreshToken = await SecureTokenStorage.readRefreshToken();
    if (refreshToken == null) {
      onSessionExpired();
      handler.next(err);
      return;
    }

    String? newAccessToken;
    try {
      newAccessToken = await _refreshAccessToken(refreshToken);
    } on DioException catch (refreshError) {
      final refreshStatus = refreshError.response?.statusCode;
      final isDefinitiveAuthFailure = refreshStatus == 401 || refreshStatus == 403;
      if (isDefinitiveAuthFailure) {
        await SecureTokenStorage.clear();
        onSessionExpired();
      }
      // Otherwise this was a network failure while refreshing -- leave the
      // session intact and just surface the original request's error.
      handler.next(err);
      return;
    }

    if (newAccessToken == null) {
      onSessionExpired();
      handler.next(err);
      return;
    }

    try {
      options.extra['authRetried'] = true;
      options.headers['Authorization'] = 'Bearer $newAccessToken';
      final response = await dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Runs (or waits on) the single in-flight refresh and returns the new
  /// access token, or null if the server rejected the refresh token.
  /// Rethrows the underlying [DioException] on network failure.
  Future<String?> _refreshAccessToken(String refreshToken) {
    final inFlight = _refreshCompleter;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    () async {
      try {
        final tokens = await refreshTokens(refreshToken);
        final accessToken = tokens['access'];
        if (accessToken == null || accessToken.isEmpty) {
          completer.complete(null);
          return;
        }
        await SecureTokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: tokens['refresh'],
        );
        completer.complete(accessToken);
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        _refreshCompleter = null;
      }
    }();

    return completer.future;
  }
}
