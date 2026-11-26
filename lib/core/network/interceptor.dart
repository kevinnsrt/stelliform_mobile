import 'package:dio/dio.dart';
import 'package:stelliform_mobile/core/network/api_endpoints.dart';

/// Callback signature providing the current Sanctum Bearer access token.
typedef TokenReader = String? Function();

/// Callback signature providing the active user's role code header for telemetry.
typedef RoleHeaderReader = String? Function();

/// Callback signature invoked when an authenticated request returns HTTP 401.
typedef UnauthorizedHandler = void Function();

/// Callback signature reporting backend reachability transitions.
typedef ConnectivityChangedHandler = void Function(bool isOnline);

/// Dio interceptor injecting Sanctum Bearer JWT tokens, reporting offline
/// network errors, and clearing expired sessions on HTTP 401 Unauthorized.
class AuthInterceptor extends Interceptor {
  /// Creates an [AuthInterceptor] wired to session and connectivity callbacks.
  AuthInterceptor({
    required TokenReader readToken,
    RoleHeaderReader? readRoleCode,
    UnauthorizedHandler? onUnauthorized,
    ConnectivityChangedHandler? onConnectivityChanged,
  }) : _readToken = readToken,
       _readRoleCode = readRoleCode,
       _onUnauthorized = onUnauthorized,
       _onConnectivityChanged = onConnectivityChanged;

  final TokenReader _readToken;
  final RoleHeaderReader? _readRoleCode;
  final UnauthorizedHandler? _onUnauthorized;
  final ConnectivityChangedHandler? _onConnectivityChanged;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    final roleCode = _readRoleCode?.call();
    if (roleCode != null && roleCode.isNotEmpty) {
      options.headers['X-User-Role'] = roleCode;
    }

    options.headers['Accept'] = 'application/json';
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _onConnectivityChanged?.call(true);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isNetworkFailure =
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout;

    if (isNetworkFailure) {
      _onConnectivityChanged?.call(false);
    } else if (err.response != null) {
      _onConnectivityChanged?.call(true);
    }

    final isLoginAttempt = err.requestOptions.path.endsWith(ApiEndpoints.login);
    if (err.response?.statusCode == 401 && !isLoginAttempt) {
      _onUnauthorized?.call();
    }
    handler.next(err);
  }
}
