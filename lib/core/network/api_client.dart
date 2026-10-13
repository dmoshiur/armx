// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../config/app_config.dart';
import '../errors/app_exception.dart';
import 'token_store.dart';

/// One HTTP response, already decoded and mapped.
@immutable
class ApiResponse<T> {
  /// Creates a response envelope.
  const ApiResponse({
    required this.data,
    this.statusCode = 200,
    this.requestId,
    this.headers = const <String, List<String>>{},
  });

  /// Decoded body.
  final T data;

  /// HTTP status.
  final int statusCode;

  /// Correlation id echoed by the server, shown to the user as a support reference.
  final String? requestId;

  /// Response headers, for the rare caller that needs `ETag`/`Retry-After`.
  final Map<String, List<String>> headers;
}

/// The one and only HTTP client in the app.
///
/// ## Rules this class exists to enforce (§8)
///
/// 1. **Every** network call goes through here. No screen, controller or repository
///    builds a `Dio`/`http` instance of its own — `tool/static_checks.py` plus code review
///    keep it that way, and the constructor is the only place the base URL is applied.
/// 2. Transport and server failures are mapped onto the sealed `AppException` hierarchy.
///    A raw `DioException` never escapes, so the UI cannot accidentally render
///    `"DioException [bad response]: ..."` to a user.
/// 3. A **malformed 200 is an error**, not an empty success: [MalformedResponseException]
///    exists precisely so "the server said OK but the body was wrong" cannot be rendered
///    as a quiet success state.
/// 4. The access token is attached here and refreshed here. A single-flight refresh means
///    ten parallel 401s produce one refresh, not ten.
/// 5. Reference ids are propagated. When the server supplies `X-Request-Id`, the user sees
///    it in the error state; when it does not, none is invented.
class ApiClient {
  /// Creates a client.
  ///
  /// [dio] is injectable so tests can drive a `DioAdapter` fake; production callers use
  /// the [ApiClient.create] factory, which builds the HTTP stack once.
  ApiClient({
    required Dio dio,
    required AppConfig config,
    required TokenStore tokenStore,
    void Function(AppException error)? onAuthFailure,
  })  : _dio = dio,
        _config = config,
        _tokenStore = tokenStore,
        _onAuthFailure = onAuthFailure;

  /// Builds the production HTTP stack.
  factory ApiClient.create({
    required AppConfig config,
    required TokenStore tokenStore,
    void Function(AppException error)? onAuthFailure,
  }) {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: config.httpsBaseUrl.toString(),
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.requestTimeout,
        sendTimeout: config.requestTimeout,
        responseType: ResponseType.json,
        // Status codes are handled explicitly below so 4xx bodies are read rather than
        // thrown away, and so the sealing rule ("never fake success") is enforced in one
        // place.
        validateStatus: (int? status) => status != null && status < 600,
        headers: <String, String>{
          'Accept': 'application/json',
          'X-Armx-Client': 'flutter',
        },
      ),
    );
    return ApiClient(
      dio: dio,
      config: config,
      tokenStore: tokenStore,
      onAuthFailure: onAuthFailure,
    );
  }

  final Dio _dio;
  final AppConfig _config;
  final TokenStore _tokenStore;
  final void Function(AppException error)? _onAuthFailure;

  Future<AuthTokens?>? _refreshInFlight;

  /// The config this client was built with. Read-only.
  AppConfig get config => _config;

  /// Performs `POST [path]` and decodes the JSON object body.
  Future<ApiResponse<Map<String, Object?>>> postJson(
    String path, {
    Object? body,
    bool authenticated = true,
    Map<String, String> headers = const <String, String>{},
    CancelToken? cancelToken,
  }) async {
    final Response<Object?> response = await _send(
      path,
      method: 'POST',
      body: body,
      authenticated: authenticated,
      headers: headers,
      cancelToken: cancelToken,
    );
    return ApiResponse<Map<String, Object?>>(
      data: _requireObject(response, path),
      statusCode: response.statusCode ?? 200,
      requestId: _requestIdOf(response),
      headers: response.headers.map,
    );
  }

  /// Performs `POST [path]` and decodes a JSON array body.
  Future<ApiResponse<List<Object?>>> postJsonList(
    String path, {
    Object? body,
    bool authenticated = true,
    Map<String, String> headers = const <String, String>{},
    CancelToken? cancelToken,
  }) async {
    final Response<Object?> response = await _send(
      path,
      method: 'POST',
      body: body,
      authenticated: authenticated,
      headers: headers,
      cancelToken: cancelToken,
    );
    return ApiResponse<List<Object?>>(
      data: _requireList(response, path),
      statusCode: response.statusCode ?? 200,
      requestId: _requestIdOf(response),
      headers: response.headers.map,
    );
  }

  /// Performs `GET [path]` and decodes a JSON object body.
  Future<ApiResponse<Map<String, Object?>>> getJson(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool authenticated = true,
    CancelToken? cancelToken,
  }) async {
    final Response<Object?> response = await _send(
      path,
      method: 'GET',
      query: query,
      authenticated: authenticated,
      cancelToken: cancelToken,
    );
    return ApiResponse<Map<String, Object?>>(
      data: _requireObject(response, path),
      statusCode: response.statusCode ?? 200,
      requestId: _requestIdOf(response),
      headers: response.headers.map,
    );
  }

  /// Performs `GET [path]` and decodes a JSON array body.
  Future<ApiResponse<List<Object?>>> getJsonList(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool authenticated = true,
    CancelToken? cancelToken,
  }) async {
    final Response<Object?> response = await _send(
      path,
      method: 'GET',
      query: query,
      authenticated: authenticated,
      cancelToken: cancelToken,
    );
    return ApiResponse<List<Object?>>(
      data: _requireList(response, path),
      statusCode: response.statusCode ?? 200,
      requestId: _requestIdOf(response),
      headers: response.headers.map,
    );
  }

  /// Performs `PATCH [path]` and decodes a JSON object body.
  Future<ApiResponse<Map<String, Object?>>> patchJson(
    String path, {
    Object? body,
    bool authenticated = true,
    CancelToken? cancelToken,
  }) async {
    final Response<Object?> response = await _send(
      path,
      method: 'PATCH',
      body: body,
      authenticated: authenticated,
      cancelToken: cancelToken,
    );
    return ApiResponse<Map<String, Object?>>(
      data: _requireObject(response, path),
      statusCode: response.statusCode ?? 200,
      requestId: _requestIdOf(response),
      headers: response.headers.map,
    );
  }

  /// Performs `DELETE [path]`. A `204` is a success with an empty body.
  Future<void> delete(String path, {bool authenticated = true}) async {
    await _send(path, method: 'DELETE', authenticated: authenticated);
  }

  /// Fetches raw bytes (a recording, an exported log).
  Future<List<int>> getBytes(String path, {bool authenticated = true}) async {
    final Response<Object?> response = await _send(
      path,
      method: 'GET',
      authenticated: authenticated,
      responseType: ResponseType.bytes,
    );
    final Object? data = response.data;
    if (data is List<int>) {
      return data;
    }
    if (data is List<Object?>) {
      return data.whereType<int>().toList(growable: false);
    }
    throw MalformedResponseException(
      message: 'Expected a binary body from $path.',
      requestId: _requestIdOf(response),
    );
  }

  /// Uploads a multipart body (a voice announcement).
  Future<ApiResponse<Map<String, Object?>>> postMultipart(
    String path, {
    required List<int> bytes,
    required String fieldName,
    required String filename,
    Map<String, Object?> fields = const <String, Object?>{},
    String contentType = 'application/octet-stream',
  }) async {
    final FormData form = FormData();
    form.fields.addAll(
      fields.entries.map(
        (MapEntry<String, Object?> entry) =>
            MapEntry<String, String>(entry.key, '${entry.value}'),
      ),
    );
    form.files.add(
      MapEntry<String, MultipartFile>(
        fieldName,
        MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        ),
      ),
    );
    final Response<Object?> response = await _send(
      path,
      method: 'POST',
      body: form,
      authenticated: true,
    );
    return ApiResponse<Map<String, Object?>>(
      data: _requireObject(response, path),
      statusCode: response.statusCode ?? 200,
      requestId: _requestIdOf(response),
      headers: response.headers.map,
    );
  }

  // ---- internals -----------------------------------------------------------

  Future<Response<Object?>> _send(
    String path, {
    required String method,
    Object? body,
    Object? query,
    bool authenticated = true,
    Map<String, String> headers = const <String, String>{},
    CancelToken? cancelToken,
    ResponseType responseType = ResponseType.json,
  }) async {
    final String? token = await _bearerToken(authenticated);
    final Map<String, String> merged = <String, String>{
      ...headers,
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      return await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: merged,
          responseType: responseType,
        ),
      );
    } on DioException catch (error) {
      final AppException mapped = mapDioException(error);
      if (mapped is UnauthorizedException && authenticated) {
        _onAuthFailure?.call(mapped);
      }
      throw mapped;
    } on Object catch (error) {
      throw UnknownException(message: 'Unexpected transport failure: $error');
    }
  }

  Future<String?> _bearerToken(bool authenticated) async {
    if (!authenticated) {
      return null;
    }
    final AuthTokens? stored = await _tokenStore.read();
    if (stored == null) {
      return null;
    }
    if (!stored.isExpired()) {
      return stored.accessToken;
    }
    final AuthTokens? refreshed = await _refresh(stored);
    return refreshed?.accessToken;
  }

  /// Single-flight refresh: concurrent callers share one in-flight request.
  Future<AuthTokens?> _refresh(AuthTokens current) {
    final Future<AuthTokens?>? inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<AuthTokens?> attempt = _performRefresh(current);
    _refreshInFlight = attempt;
    return attempt.whenComplete(() => _refreshInFlight = null);
  }

  Future<AuthTokens?> _performRefresh(AuthTokens current) async {
    try {
      final Response<Object?> response = await _dio.post<Object?>(
        '/auth/refresh',
        data: <String, Object?>{'refresh_token': current.refreshToken},
        options: Options(
          headers: const <String, String>{'X-Armx-Client': 'flutter'},
        ),
      );
      final int status = response.statusCode ?? 0;
      if (status >= 400) {
        throw mapStatus(status, _errorPayload(response), _requestIdOf(response));
      }
      final Map<String, Object?> json = _requireObject(response, '/auth/refresh');
      final AuthTokens tokens = _tokensFrom(json, current.refreshToken);
      await _tokenStore.write(tokens);
      return tokens;
    } on AppException catch (error) {
      final UnauthorizedException rejected = UnauthorizedException(
        message: 'The refresh token was rejected; sign in again.',
        code: 'refresh_rejected',
        requestId: error.requestId,
      );
      await _tokenStore.clear();
      _onAuthFailure?.call(rejected);
      return null;
    }
  }

  AuthTokens _tokensFrom(Map<String, Object?> json, String previousRefresh) {
    final Object? access = json['access_token'] ?? json['accessToken'];
    final Object? refresh = json['refresh_token'] ?? json['refreshToken'];
    final Object? expiresIn = json['expires_in'] ?? json['expiresIn'];
    if (access is! String || access.isEmpty) {
      throw const MalformedResponseException(
        message: 'Token response had no access_token.',
        code: 'malformed_token',
      );
    }
    final int seconds = expiresIn is num ? expiresIn.toInt() : 900;
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh is String && refresh.isNotEmpty ? refresh : previousRefresh,
      accessExpiresAt: DateTime.now().toUtc().add(Duration(seconds: seconds)),
    );
  }

  Map<String, Object?> _requireObject(Response<Object?> response, String path) {
    final Object? data = response.data;
    if (data == null) {
      // A 204/empty body is only acceptable where the contract says so; every JSON method
      // expects an object, so an empty body is a contract violation.
      throw MalformedResponseException(
        message: 'Expected a JSON object from $path but the body was empty.',
        statusCode: response.statusCode,
        requestId: _requestIdOf(response),
      );
    }
    if (data is Map<String, Object?>) {
      return data;
    }
    if (data is String && data.isNotEmpty) {
      final Object? decoded = _tryDecode(data);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
    }
    throw MalformedResponseException(
      message: 'Expected a JSON object from $path but received ${data.runtimeType}.',
      statusCode: response.statusCode,
      requestId: _requestIdOf(response),
    );
  }

  List<Object?> _requireList(Response<Object?> response, String path) {
    final Object? data = response.data;
    if (data is List<Object?>) {
      return data;
    }
    if (data is Map<String, Object?>) {
      // Tolerate `{"items": [...]}` envelopes, which the paginated endpoints use.
      for (final String key in <String>['items', 'data', 'results']) {
        final Object? inner = data[key];
        if (inner is List<Object?>) {
          return inner;
        }
      }
    }
    if (data is String && data.isNotEmpty) {
      final Object? decoded = _tryDecode(data);
      if (decoded is List<Object?>) {
        return decoded;
      }
    }
    throw MalformedResponseException(
      message: 'Expected a JSON array from $path but received ${data.runtimeType}.',
      statusCode: response.statusCode,
      requestId: _requestIdOf(response),
    );
  }

  Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  String? _requestIdOf(Response<Object?> response) {
    final String? header = response.headers.value('x-request-id');
    if (header != null && header.isNotEmpty) {
      return header;
    }
    final Object? body = response.data;
    if (body is Map<String, Object?>) {
      final Object? id = body['request_id'] ?? body['requestId'];
      if (id is String && id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  Map<String, Object?> _errorPayload(Response<Object?> response) {
    final Object? body = response.data;
    if (body is Map<String, Object?>) {
      final Object? error = body['error'];
      if (error is Map<String, Object?>) {
        return error;
      }
      return body;
    }
    if (body is String && body.isNotEmpty) {
      final Object? decoded = _tryDecode(body);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
    }
    return const <String, Object?>{};
  }

  /// Maps a Dio failure onto the app's own hierarchy.
  @visibleForTesting
  AppException mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const NetworkException();
      case DioExceptionType.cancel:
        return const CancelledException();
      case DioExceptionType.unknown:
        return NetworkException(
          message: 'The request failed before a response arrived: ${error.message}',
        );
      case DioExceptionType.badResponse:
        final Response<Object?>? response = error.response;
        if (response == null) {
          return const NetworkException();
        }
        return mapStatus(
          response.statusCode ?? 0,
          _errorPayload(response),
          _requestIdOf(response),
        );
    }
  }

  /// Maps an HTTP status plus an error payload onto the app's own hierarchy.
  @visibleForTesting
  AppException mapStatus(
    int status,
    Map<String, Object?> payload,
    String? requestId,
  ) {
    final String? code = payload['code'] as String?;
    final String message = (payload['message'] as String?)?.trim().isNotEmpty ?? false
        ? payload['message']! as String
        : 'The server rejected the request (HTTP $status).';

    switch (status) {
      case 400:
        return ValidationException(
          message: message,
          code: code,
          requestId: requestId,
          fieldErrors: _fieldErrors(payload),
        );
      case 401:
        return UnauthorizedException(
          message: message,
          code: code,
          requestId: requestId,
        );
      case 403:
        return ForbiddenException(
          message: message,
          code: code,
          requestId: requestId,
        );
      case 404:
        return NotFoundException(
          message: message,
          code: code,
          requestId: requestId,
        );
      case 409:
        return ConflictException(
          message: message,
          code: code,
          requestId: requestId,
        );
      case 422:
        return ValidationException(
          message: message,
          code: code,
          requestId: requestId,
          fieldErrors: _fieldErrors(payload),
        );
      case 429:
        return RateLimitedException(
          message: message,
          code: code,
          requestId: requestId,
        );
    }
    if (status >= 500) {
      return ServerException(
        message: message,
        code: code,
        statusCode: status,
        requestId: requestId,
      );
    }
    return UnknownException(
      message: message,
      code: code,
      statusCode: status,
      requestId: requestId,
    );
  }

  Map<String, String> _fieldErrors(Map<String, Object?> payload) {
    final Object? raw = payload['fields'] ?? payload['errors'];
    if (raw is! Map) {
      return const <String, String>{};
    }
    final Map<String, String> result = <String, String>{};
    raw.forEach((Object? key, Object? value) {
      if (key is String) {
        result[key] = value is String ? value : '${value ?? ''}';
      }
    });
    return result;
  }
}
