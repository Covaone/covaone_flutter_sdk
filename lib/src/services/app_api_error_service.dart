import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';

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
  final String? message;
  final DateTime timestamp;

  const AppApiErrorEvent({
    required this.source,
    required this.method,
    required this.timestamp,
    this.uri,
    this.statusCode,
    this.message,
  });
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
          message: response.statusMessage,
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
            message: err.message,
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
