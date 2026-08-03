import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../data/local/session_storage.dart';
import '../data/repositories/chat_repository.dart';
import '../blocs/session/session_bloc.dart';

/// Registers host-app FCM tokens with the Covaone backend.
///
/// The host app owns Firebase; this service only posts the token once a
/// session has an identified customer (post set-profile / SessionLoaded).
class PushTokenService {
  final ChatRepository _chatRepository;
  final SessionStorage _sessionStorage;

  String? _pendingToken;
  String? _pendingPlatform;
  String? _pendingDeviceId;
  String? _pendingAppBundleId;
  bool _flushInFlight = false;

  PushTokenService({
    required ChatRepository chatRepository,
    required SessionStorage sessionStorage,
  })  : _chatRepository = chatRepository,
        _sessionStorage = sessionStorage;

  /// Queue [token] and flush when a profiled session is available.
  Future<void> registerPushToken({
    required String token,
    String? platform,
    String? deviceId,
    String? appBundleId,
  }) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;

    _pendingToken = trimmed;
    _pendingPlatform = _normalizePlatform(platform);
    _pendingDeviceId = deviceId?.trim();
    _pendingAppBundleId = appBundleId?.trim();
    await _sessionStorage.savePendingPushToken(trimmed);
    await flushIfPossible();
  }

  Future<void> flushIfPossible() async {
    if (_flushInFlight) return;
    _flushInFlight = true;
    try {
      final token = (_pendingToken ?? await _sessionStorage.getPendingPushToken())
          ?.trim();
      if (token == null || token.isEmpty) return;

      final sessionId = await _sessionStorage.getSessionId();
      if (sessionId == null || sessionId.isEmpty) return;

      // Backend requires set-profile (customer_id). Prefer SessionLoaded.
      // We still attempt register-device; API returns 400 if unprofiled.
      await _chatRepository.registerDevice(
        sessionId: sessionId,
        fcmToken: token,
        platform: _pendingPlatform ?? _detectPlatform(),
        deviceId: _pendingDeviceId,
        appBundleId: _pendingAppBundleId,
      );

      _pendingToken = null;
      await _sessionStorage.clearPendingPushToken();
    } catch (e) {
      // Soft-fail: keep pending token and retry on next SessionLoaded.
      debugPrint('Covaone PushTokenService flush failed: $e');
    } finally {
      _flushInFlight = false;
    }
  }

  /// Call when [SessionBloc] reaches [SessionLoaded].
  Future<void> onSessionLoaded(SessionLoaded state) => flushIfPossible();

  static String? _normalizePlatform(String? platform) {
    final p = platform?.trim().toLowerCase();
    if (p == null || p.isEmpty) return null;
    if (p == 'ios' || p == 'android' || p == 'web') return p;
    return null;
  }

  static String _detectPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
    } catch (_) {}
    return 'android';
  }
}
