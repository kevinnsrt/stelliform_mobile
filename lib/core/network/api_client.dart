import 'package:dio/dio.dart';
import 'package:stelliform_mobile/core/network/api_endpoints.dart';
import 'package:stelliform_mobile/core/network/interceptor.dart';

/// Normalized API failure exception surfaced across repositories and UI layers.
class ApiException implements Exception {
  /// Creates an [ApiException] matching Laravel's error envelope.
  const ApiException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.fieldErrors = const {},
    this.isTimeout = false,
  });

  /// User-facing error description.
  final String message;

  /// Optional HTTP status code returned by the backend.
  final int? statusCode;

  /// Machine-readable backend error code (e.g. `STOK_TIDAK_CUKUP`, `UNAUTHENTICATED`).
  final String? errorCode;

  /// Per-field Laravel validation error messages.
  final Map<String, List<String>> fieldErrors;

  /// Whether the failure was caused by a connection, send, or receive timeout.
  final bool isTimeout;

  /// Whether this error represents an expired or missing authentication session.
  bool get isUnauthorized => statusCode == 401;

  /// Whether this error represents a server-side 5xx failure.
  bool get isServerError => (statusCode ?? 0) >= 500;

  /// Returns a concise title suitable for error dialogs.
  String get dialogTitle {
    if (isTimeout) return 'Koneksi Habis Waktu';
    return switch (statusCode) {
      400 => 'Permintaan Tidak Valid (400)',
      401 => 'Sesi Tidak Valid (401)',
      403 => 'Akses Ditolak (403)',
      404 => 'Data Tidak Ditemukan (404)',
      409 => 'Konflik Data (409)',
      422 => 'Validasi Data Gagal (422)',
      429 => 'Terlalu Banyak Permintaan (429)',
      int code when code >= 500 => 'Gangguan Server ($code)',
      _ => 'Kesalahan Jaringan',
    };
  }

  /// Combines [message] with the first field-level validation hint when present.
  String get detailedMessage {
    if (fieldErrors.isEmpty) return message;
    final firstEntry = fieldErrors.entries.first;
    if (firstEntry.value.isEmpty) return message;
    final firstDetail = firstEntry.value.first;
    if (message.contains(firstDetail)) return message;
    return '$message ($firstDetail)';
  }

  @override
  String toString() => 'ApiException($statusCode, $errorCode): $message';
}

/// Configured HTTP client wrapper built on [Dio] with Sanctum Bearer interception.
class ApiClient {
  /// Creates an [ApiClient] targeting [baseUrl] with [AuthInterceptor].
  ApiClient({
    required TokenReader readToken,
    RoleHeaderReader? readRoleCode,
    UnauthorizedHandler? onUnauthorized,
    ConnectivityChangedHandler? onConnectivityChanged,
    String baseUrl = ApiEndpoints.baseUrl,
    HttpClientAdapter? httpClientAdapter,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 15),
           sendTimeout: const Duration(seconds: 15),
           contentType: Headers.jsonContentType,
           headers: const {'Accept': 'application/json'},
         ),
       ) {
    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
    }
    _dio.interceptors.add(
      AuthInterceptor(
        readToken: readToken,
        readRoleCode: readRoleCode,
        onUnauthorized: onUnauthorized,
        onConnectivityChanged: onConnectivityChanged,
      ),
    );
  }

  final Dio _dio;

  /// Underlying [Dio] instance.
  Dio get dio => _dio;

  /// Executes an HTTP GET request to [path].
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  /// Executes an HTTP POST request to [path] with optional JSON [data].
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  /// Executes a `multipart/form-data` HTTP POST upload to [path].
  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: formData,
        queryParameters: queryParameters,
        onSendProgress: onSendProgress,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  /// Executes an HTTP PUT request to [path] with JSON [data].
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  /// Executes an HTTP PATCH request to [path] with partial JSON [data].
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  /// Executes an HTTP DELETE request to [path].
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  /// Unwraps the standard Laravel `{ "success": true, "data": ... }` response payload.
  static dynamic unwrapData(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  /// Extracts a list from either `{ "data": [...] }` or a bare JSON list.
  static List<Map<String, dynamic>> unwrapList(dynamic body) {
    final raw = unwrapData(body);
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    return const [];
  }

  ApiException _mapException(DioException error) {
    final statusCode = error.response?.statusCode;
    final payload = error.response?.data;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiException(
        'Koneksi ke server ERP habis waktu (timeout). Pastikan backend aktif dan jaringan stabil.',
        statusCode: statusCode,
        errorCode: 'TIMEOUT',
        isTimeout: true,
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return ApiException(
        'Tidak dapat terhubung ke server ERP (${_dio.options.baseUrl}). Periksa koneksi jaringan lokal Anda.',
        statusCode: statusCode,
        errorCode: 'CONNECTION_ERROR',
      );
    }

    String? serverMessage;
    String? errorCode;
    final fieldErrors = <String, List<String>>{};

    if (payload is Map<String, dynamic>) {
      if (payload['message'] is String &&
          (payload['message'] as String).trim().isNotEmpty) {
        serverMessage = (payload['message'] as String).trim();
      }
      if (payload['error_code'] is String) {
        errorCode = payload['error_code'] as String;
      }
      final rawErrors = payload['errors'];
      if (rawErrors is Map) {
        for (final entry in rawErrors.entries) {
          final key = entry.key.toString();
          if (entry.value is List) {
            fieldErrors[key] = (entry.value as List)
                .map((item) => item.toString())
                .toList(growable: false);
          } else if (entry.value != null) {
            fieldErrors[key] = [entry.value.toString()];
          }
        }
      }
    }

    final fallbackMessage = switch (statusCode) {
      400 =>
        'Permintaan tidak valid (400 Bad Request). Periksa parameter Anda.',
      401 => 'Sesi login berakhir atau token tidak sah (401 Unauthorized).',
      403 => 'Akun atau peran Anda tidak memiliki izin akses (403 Forbidden).',
      404 => 'Data atau endpoint tidak ditemukan (404 Not Found).',
      409 => 'Data sedang digunakan oleh transaksi lain (409 Conflict).',
      422 => 'Validasi data gagal. Periksa kembali kolom yang diisi.',
      429 => 'Terlalu banyak percobaan dalam waktu singkat. Coba 1 menit lagi.',
      int code when code >= 500 =>
        'Terjadi kesalahan internal pada server ERP ($code). Silakan coba lagi nanti.',
      _ => error.message ?? 'Terjadi kesalahan jaringan yang tidak terduga.',
    };

    return ApiException(
      serverMessage ?? fallbackMessage,
      statusCode: statusCode,
      errorCode: errorCode,
      fieldErrors: fieldErrors,
    );
  }
}
