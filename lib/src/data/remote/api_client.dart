import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config.dart';
import '../../core/constants.dart';

/// Dio-based REST client. All endpoints use POST with a JSON body.
/// Includes a debug logger and a transparent retry interceptor (≤2 retries,
/// exponential back-off).
class ApiClient {
  late final Dio _dio;

  ApiClient({required CovaoneConfig config}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: config.apiBase.endsWith('/')
            ? config.apiBase
            : '${config.apiBase}/',
        connectTimeout: CovaoneConstants.connectTimeout,
        receiveTimeout: CovaoneConstants.receiveTimeout,
        sendTimeout: CovaoneConstants.sendTimeout,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
          CovaoneConstants.sdkInternalRequestHeader: 'true',
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(_LoggingInterceptor());
    }
    _dio.interceptors.add(_RetryInterceptor(_dio));
  }

  // ── Session ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> initiateSession(String publicKey) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'initiate-session',
      data: {'public_key': publicKey, 'ip': ''},
    );
    return _unwrap(response);
  }

  Future<Map<String, dynamic>> getSingleSession(String sessionId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'get-single-session',
      data: {'session_id': sessionId},
    );
    debugPrint(">>>>>> response here <<<<<<");
    debugPrint(">>>>>> ${response.toString()} <<<<<<");

    return _unwrap(response);
  }

  Future<Map<String, dynamic>> setProfile({
    required String sessionId,
    required String email,
    required String name,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'set-profile',
      data: {'session_id': sessionId, 'email': email, 'name': name},
    );
    return _unwrap(response);
  }

  // ── Broadcasts ────────────────────────────────────────────────────────────

  Future<dynamic> getBroadcasts(String sessionId) async {
    final response = await _dio.post<dynamic>(
      'broadcasts/widget/get',
      data: {'session_id': sessionId},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getSingleBroadcast(String broadcastId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'broadcast/get',
      data: {'broadcast_id': broadcastId},
    );
    return _unwrap(response);
  }

  // ── FAQs ──────────────────────────────────────────────────────────────────

  Future<dynamic> getAllFaqs(String sessionId) async {
    final response = await _dio.post<dynamic>(
      'faqs/users/get/all',
      data: {'session_id': sessionId},
    );
    return response.data;
  }

  // ── WebRTC ────────────────────────────────────────────────────────────────

  /// Short-lived TURN/STUN credentials for voice calls.
  ///
  /// Must be GET — POST returns 405 on the backend.
  Future<Map<String, dynamic>> getTurnCredentials({
    required String sessionId,
    required String publicKey,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'webrtc/turn-credentials',
      queryParameters: {
        'session_id': sessionId,
        'public_key': publicKey,
      },
    );
    return _unwrap(response);
  }

  // ── File upload ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadFile({
    required String conversationId,
    required String origin,
    required String message,
    required String messageType,
    required String fileBase64,
    required String filename,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'file-upload',
      data: {
        'conversation_id': conversationId,
        'origin': origin,
        'message': message,
        'message_type': messageType,
        'file': fileBase64,
        'filename': filename,
      },
    );
    return _unwrap(response);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _unwrap(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty response body',
      );
    }
    return data;
  }
}

// ── Logging interceptor ────────────────────────────────────────────────────

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[Covaone] → ${options.method} ${options.uri}');
    if (options.data != null) {
      debugPrint('[Covaone]   body: ${jsonEncode(options.data)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
        '[Covaone] ← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[Covaone] ✗ ${err.requestOptions.uri}: ${err.message}');
    handler.next(err);
  }
}

// ── Retry interceptor (up to 2 retries, exponential back-off) ─────────────

class _RetryInterceptor extends Interceptor {
  final Dio _dio;

  static const _retryCountKey = '_covaone_retry_count';

  _RetryInterceptor(this._dio);

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra[_retryCountKey] as int?) ?? 0;

    if (_isRetryable(err) && attempt < CovaoneConstants.maxRetryAttempts) {
      final delay = CovaoneConstants.retryBaseDelay * (1 << attempt);
      await Future<void>.delayed(delay);

      final retryOptions = err.requestOptions
        ..extra[_retryCountKey] = attempt + 1;

      try {
        final response = await _dio.fetch<dynamic>(retryOptions);
        handler.resolve(response);
      } on DioException catch (retryErr) {
        handler.next(retryErr);
      }
    } else {
      handler.next(err);
    }
  }

  bool _isRetryable(DioException err) =>
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.sendTimeout ||
      err.type == DioExceptionType.unknown ||
      err.type == DioExceptionType.connectionError;
}
