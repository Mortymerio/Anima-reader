// ignore: unused_import
import 'package:dio/dio.dart';
import '../constants/strings.dart';

/// Categories of errors that can occur in the app.
enum ErrorType {
  noConnection,
  invalidToken,
  repoNotFound,
  rateLimit,
  unknown,
}

/// A user-friendly exception with a displayable message.
class AppException implements Exception {
  final ErrorType type;
  final String message;
  final Object? originalError;

  const AppException({
    required this.type,
    required this.message,
    this.originalError,
  });

  /// Translate a raw exception (typically from Dio) into a user-friendly AppException.
  factory AppException.from(Object error) {
    if (error is AppException) return error;

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionError:
          return const AppException(
            type: ErrorType.noConnection,
            message: S.errorNoConnection,
          );
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 401 || statusCode == 403) {
            return AppException(
              type: ErrorType.invalidToken,
              message: S.errorInvalidToken,
              originalError: error,
            );
          }
          if (statusCode == 404) {
            return AppException(
              type: ErrorType.repoNotFound,
              message: S.errorRepoNotFound,
              originalError: error,
            );
          }
          if (statusCode == 429) {
            return AppException(
              type: ErrorType.rateLimit,
              message: S.errorRateLimit,
              originalError: error,
            );
          }
          return AppException(
            type: ErrorType.unknown,
            message: S.errorUnknown,
            originalError: error,
          );
        default:
          return AppException(
            type: ErrorType.unknown,
            message: S.errorUnknown,
            originalError: error,
          );
      }
    }

    return AppException(
      type: ErrorType.unknown,
      message: S.errorUnknown,
      originalError: error,
    );
  }

  @override
  String toString() => 'AppException($type): $message';
}
