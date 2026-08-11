import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

/// Retries a request after a transient failure (connection/receive timeout,
/// a connection error, or a 502/503/504 from the server) with exponential
/// backoff plus jitter, up to [maxRetries] times. A definitive response like
/// 400/401/403/404 is never retried -- a second identical request wouldn't
/// come back any differently.
///
/// This is meant to smooth over brief network hiccups, not to replace an
/// offline story: [maxRetries] attempts of ~1s/2s/4s backoff cap out well
/// under 10 seconds, so a real outage still surfaces as a failure quickly
/// enough for callers to fall back to cached data instead of hanging.
///
/// By default only `GET`/`HEAD` requests are retried. Every other method
/// (POST/PUT/PATCH/DELETE) is left alone unless the call site explicitly
/// opts in via `options.extra['retryable'] = true` -- e.g. once an endpoint
/// has its own idempotency-key mechanism. This is deliberate: blindly
/// retrying something like "add to cart" or a future checkout/order-creation
/// call after a timeout can silently duplicate it if the original request
/// actually reached the server and only the response was lost in transit.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    Random? random,
  }) : _random = random ?? Random();

  /// The Dio instance to replay the request on. Must be the same instance
  /// this interceptor is attached to.
  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;
  final Random _random;

  static const _retryableStatusCodes = {502, 503, 504};

  // Up to this much extra random delay is added on top of each backoff step
  // so that several requests which failed at the same moment (e.g. a whole
  // screen's worth of initial loads) don't all retry in lockstep.
  static const _maxJitter = Duration(milliseconds: 400);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final attempt = (options.extra['retryAttempt'] as int?) ?? 0;

    if (attempt >= maxRetries || !_isRetryable(err, options)) {
      handler.next(err);
      return;
    }

    await Future.delayed(_backoffDelay(attempt));

    try {
      // RequestOptions.copyWith preserves headers, query parameters, body,
      // and every other Dio option (including the Authorization header
      // AuthInterceptor attached) -- only `extra` is overridden here, to
      // record the attempt count and guard against retrying forever.
      final retryOptions = options.copyWith(
        extra: {...options.extra, 'retryAttempt': attempt + 1},
      );
      final response = await dio.fetch(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isRetryable(DioException err, RequestOptions options) {
    return _isRetryableMethod(options) && _isTransientError(err);
  }

  bool _isRetryableMethod(RequestOptions options) {
    final method = options.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD') return true;
    return options.extra['retryable'] == true;
  }

  bool _isTransientError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        return status != null && _retryableStatusCodes.contains(status);
      default:
        return false;
    }
  }

  // attempt 0 -> baseDelay * 1 (+jitter), attempt 1 -> baseDelay * 2, attempt
  // 2 -> baseDelay * 4 -- i.e. ~1s/2s/4s at the default 1-second base.
  Duration _backoffDelay(int attempt) {
    final exponential = baseDelay * (1 << attempt);
    final jitter = Duration(milliseconds: _random.nextInt(_maxJitter.inMilliseconds));
    return exponential + jitter;
  }
}
