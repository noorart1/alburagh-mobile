import 'package:dio/dio.dart';

/// Turns a caught exception into a short, friendly Arabic sentence that's
/// safe to show a customer. Never surfaces the raw exception text (a
/// DioException's verbose toString(), a bare HTTP status code, a stack
/// trace fragment) -- that reads as a developer error dump, not something a
/// shopper can understand or act on.
///
/// [fallback] is shown whenever the error isn't one of the specific,
/// recognizable cases below (a network-level failure or a handful of common
/// HTTP statuses) -- callers should pass something naming the action that
/// failed (e.g. "تعذر تحميل السلة، حاول مرة أخرى") rather than relying on
/// the default, so the message stays useful even for an unrecognized error.
String friendlyErrorMessage(
  Object error, {
  String fallback = 'حدث خطأ غير متوقع، حاول مرة أخرى',
}) {
  if (error is! DioException) return fallback;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'استغرقت العملية وقتاً أطول من المعتاد، تحقق من اتصالك وحاول مرة أخرى';
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return 'تعذر الاتصال بالإنترنت، تحقق من اتصالك وحاول مرة أخرى';
    case DioExceptionType.badResponse:
      return _describeStatus(error.response?.statusCode) ?? fallback;
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
    default:
      return fallback;
  }
}

String? _describeStatus(int? status) {
  if (status == null) return null;
  if (status == 401 || status == 403) {
    return 'انتهت صلاحية الجلسة، الرجاء تسجيل الدخول مرة أخرى';
  }
  if (status == 429) return 'عدد الطلبات كبير حالياً، حاول مرة أخرى بعد قليل';
  if (status >= 500) return 'الخادم غير متاح حالياً، حاول مرة أخرى بعد قليل';
  // Other statuses (400/404/...) mean different things depending on the
  // action that failed -- let the caller's own fallback describe it.
  return null;
}
