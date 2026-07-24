import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../data/local/session_storage.dart';
import '../data/remote/api_client.dart';

/// Fetches short-lived TURN/STUN credentials from the backend and maps them
/// to the `iceServers` format expected by [createPeerConnection].
class TurnIceService {
  TurnIceService({
    required ApiClient apiClient,
    required SessionStorage sessionStorage,
    required CovaoneConfig config,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage,
        _config = config;

  final ApiClient _apiClient;
  final SessionStorage _sessionStorage;
  final CovaoneConfig _config;

  /// STUN-only fallback when the credentials endpoint is unavailable.
  static const List<Map<String, dynamic>> fallbackIceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
  ];

  List<Map<String, dynamic>>? _cachedServers;
  DateTime? _cacheExpiresAt;
  Future<List<Map<String, dynamic>>>? _inFlight;

  /// Returns ICE servers, using an in-memory cache when still valid.
  Future<List<Map<String, dynamic>>> getIceServers() => fetchTurnIceServers();

  /// Warms the cache during ringing so accept can reuse credentials quickly.
  void prefetch() {
    unawaited(fetchTurnIceServers());
  }

  /// Fetches TURN/STUN servers from `GET /webrtc/turn-credentials`.
  ///
  /// Falls back to [fallbackIceServers] on any error or missing session.
  Future<List<Map<String, dynamic>>> fetchTurnIceServers() async {
    if (_cachedServers != null &&
        _cacheExpiresAt != null &&
        DateTime.now().isBefore(_cacheExpiresAt!)) {
      return _cachedServers!;
    }

    if (_inFlight != null) return _inFlight!;

    _inFlight = _fetchTurnIceServers();
    try {
      return await _inFlight!;
    } finally {
      _inFlight = null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTurnIceServers() async {
    try {
      final sessionId = await _sessionStorage.getSessionId();
      if (sessionId == null || sessionId.isEmpty) {
        // debugPrint('[Covaone TURN] No session_id — using STUN-only fallback');
        return fallbackIceServers;
      }

      final response = await _apiClient.getTurnCredentials(
        sessionId: sessionId,
        publicKey: _config.publicKey,
      );

      final servers = _mapIceServers(response);
      if (servers.isEmpty) {
        // debugPrint('[Covaone TURN] Empty iceServers — using STUN-only fallback');
        return fallbackIceServers;
      }

      final ttlSeconds = (response['ttl'] as num?)?.toInt() ?? 3600;
      // Refresh one minute before expiry so calls near the boundary stay safe.
      final cacheTtl =
          Duration(seconds: ttlSeconds > 60 ? ttlSeconds - 60 : ttlSeconds);
      _cachedServers = servers;
      _cacheExpiresAt = DateTime.now().add(cacheTtl);

      // debugPrint('[Covaone TURN] Loaded ${servers.length} ICE server(s)');
      return servers;
    } catch (e) {
      // debugPrint('[Covaone TURN] fetch failed: $e — using STUN-only fallback');
      return fallbackIceServers;
    }
  }

  /// Clears cached credentials (e.g. on SDK destroy).
  void clearCache() {
    _cachedServers = null;
    _cacheExpiresAt = null;
    _inFlight = null;
  }

  /// Maps the API `iceServers` array to flutter_webrtc config entries.
  static List<Map<String, dynamic>> _mapIceServers(
      Map<String, dynamic> response) {
    final raw = response['iceServers'];
    if (raw is! List) return const [];

    final servers = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final urls = map['urls'];
      if (urls == null) continue;

      final server = <String, dynamic>{'urls': urls};

      final username = map['username'];
      final credential = map['credential'];
      if (username is String && username.isNotEmpty) {
        server['username'] = username;
      }
      if (credential is String && credential.isNotEmpty) {
        server['credential'] = credential;
      }

      servers.add(server);
    }
    return servers;
  }
}
