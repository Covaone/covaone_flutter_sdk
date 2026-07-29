import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../data/models/message_error_info.dart';

/// Source that produced a host-app API error report.
enum AppApiErrorSource {
  /// Captured via SDK-installed [HttpOverrides.global].
  automaticGlobalHttp,

  /// Captured via the host app's Dio client interceptor.
  hostDioInterceptor,

  /// Explicitly reported by the host app.
  manualReport,
}

/// Structured API error event emitted by host-app monitoring integrations.
class AppApiErrorEvent {
  final AppApiErrorSource source;
  final String method;
  final Uri? uri;
  final int? statusCode;

  /// Full error payload for agents — response body / error object when
  /// available (Map, List, or String), not just the HTTP reason phrase.
  final Object? message;
  final DateTime timestamp;

  const AppApiErrorEvent({
    required this.source,
    required this.method,
    required this.timestamp,
    this.uri,
    this.statusCode,
    this.message,
  });

  /// Friendly draft for the chat composer when the user taps the help card.
  /// Technical API details are withheld — they go on the socket as `error-info`.
  String toSupportDraftMessage() {
    return 'Hi, I need help — I just ran into an error while using the app.';
  }

  /// Socket-only payload for `messageData['error-info']`.
  MessageErrorInfo toMessageErrorInfo() {
    return MessageErrorInfo(
      url: uri?.toString(),
      data: {
        'method': method,
        if (statusCode != null) 'status_code': statusCode,
        if (message != null) 'message': _socketSafeMessage(message),
        'source': source.name,
        'timestamp': timestamp.toIso8601String(),
      },
    );
  }

  /// Prefer structured JSON bodies; fall back to a trimmed string.
  static Object? _socketSafeMessage(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw is Map || raw is List || raw is num || raw is bool) {
      return raw;
    }
    final asString = raw.toString().trim();
    return asString.isEmpty ? null : asString;
  }

  /// Normalize a response body / Dio `data` into a socket-safe error payload.
  static Object? normalizeErrorBody(Object? body, {String? fallback}) {
    if (body == null) {
      final trimmed = fallback?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }
    if (body is Map || body is List || body is num || body is bool) {
      return body;
    }
    if (body is String) {
      final trimmed = body.trim();
      if (trimmed.isEmpty) {
        final fb = fallback?.trim();
        return (fb == null || fb.isEmpty) ? null : fb;
      }
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        return trimmed;
      }
    }
    if (body is List<int>) {
      return normalizeErrorBody(
        utf8.decode(body, allowMalformed: true),
        fallback: fallback,
      );
    }
    return normalizeErrorBody(body.toString(), fallback: fallback);
  }
}

/// Callback signature for host-app API error notifications.
typedef AppApiErrorCallback = void Function(AppApiErrorEvent event);

/// Central sink for host-app API errors and popup prompt throttling.
class AppApiErrorService {
  DateTime? _lastPromptAt;
  AppApiErrorCallback? _onErrorCallback;
  AppApiErrorEvent? _latestEvent;

  final _eventsController = StreamController<AppApiErrorEvent>.broadcast();
  final _promptController = StreamController<AppApiErrorEvent>.broadcast();
  final ValueNotifier<int> eventTick = ValueNotifier<int>(0);

  Stream<AppApiErrorEvent> get events => _eventsController.stream;
  Stream<AppApiErrorEvent> get promptStream => _promptController.stream;
  AppApiErrorEvent? get latestEvent => _latestEvent;

  void setOnErrorCallback(AppApiErrorCallback? callback) {
    _onErrorCallback = callback;
  }

  void report(AppApiErrorEvent event) {
    if (_eventsController.isClosed) return;
    _latestEvent = event;
    eventTick.value++;
    _eventsController.add(event);
    _onErrorCallback?.call(event);

    if (_shouldShowPrompt(event.timestamp)) {
      _lastPromptAt = event.timestamp;
      _promptController.add(event);
    }
  }

  bool _shouldShowPrompt(DateTime now) {
    final last = _lastPromptAt;
    if (last == null) return true;
    return now.difference(last) >= CovaoneConstants.hostApiPromptCooldown;
  }

  void dispose() {
    _eventsController.close();
    _promptController.close();
    eventTick.dispose();
  }
}

/// Interceptor for host-app Dio clients.
class HostAppApiDioInterceptor extends Interceptor {
  final AppApiErrorService _service;

  HostAppApiDioInterceptor({required AppApiErrorService service})
      : _service = service;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final statusCode = response.statusCode;
    if (statusCode != null &&
        statusCode >= 300 &&
        !_isSdkTagged(response.requestOptions)) {
      _service.report(
        AppApiErrorEvent(
          source: AppApiErrorSource.hostDioInterceptor,
          method: response.requestOptions.method,
          uri: response.requestOptions.uri,
          statusCode: statusCode,
          message: AppApiErrorEvent.normalizeErrorBody(
            response.data,
            fallback: response.statusMessage,
          ),
          timestamp: DateTime.now(),
        ),
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_isSdkTagged(err.requestOptions)) {
      final statusCode = err.response?.statusCode;
      if (statusCode == null || statusCode >= 300) {
        _service.report(
          AppApiErrorEvent(
            source: AppApiErrorSource.hostDioInterceptor,
            method: err.requestOptions.method,
            uri: err.requestOptions.uri,
            statusCode: statusCode,
            message: AppApiErrorEvent.normalizeErrorBody(
              err.response?.data,
              fallback: err.message ?? err.response?.statusMessage,
            ),
            timestamp: DateTime.now(),
          ),
        );
      }
    }
    handler.next(err);
  }

  bool _isSdkTagged(RequestOptions options) {
    final headerValue =
        options.headers[CovaoneConstants.sdkInternalRequestHeader];
    return headerValue?.toString().toLowerCase() == 'true';
  }
}
