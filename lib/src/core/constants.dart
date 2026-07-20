/// SDK-wide constants: SharedPreferences keys, network timeouts, and limits.
abstract final class CovaoneConstants {
  // ── SharedPreferences keys ──────────────────────────────────────────────
  static const String sessionIdKey = '__x_loadID';
  static const String emailKey = '__x_vedwx';
  static const String configKey = '__x_vlclr';
  static const String sessionCacheKey = '__x_session_cache';
  static const String sessionSyncAtKey = '__x_session_sync_at';
  static const String broadcastCacheKey = '__x_broadcast_cache';
  static const String broadcastSyncAtKey = '__x_broadcast_sync_at';
  static const String broadcastViewedKey = 'covaone__xrbroadview';
  static const String lastChatOpenedAtKey = '__x_last_chat_opened_at';
  static const String lastMessageAlertClearedAtKey =
      '__x_last_message_alert_cleared_at';
  static const String pendingMessageAlertsKey = '__x_pending_message_alerts';
  static const String dismissedMessageAlertIdsKey =
      '__x_dismissed_message_alert_ids';

  /// Default TTL before a cached session is refreshed from the network.
  static const Duration defaultSessionCacheTtl = Duration(hours: 24);

  /// Default TTL before cached broadcasts are refreshed from the network.
  static const Duration defaultBroadcastCacheTtl = Duration(hours: 24);

  // ── Network ─────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Maximum number of automatic retries on transient network errors.
  static const int maxRetryAttempts = 2;

  /// Base delay for exponential back-off (doubles per attempt).
  static const Duration retryBaseDelay = Duration(milliseconds: 500);
  static const String sdkInternalRequestHeader = 'x-covaone-sdk-request';
  static const Duration hostApiPromptDisplayDuration = Duration(seconds: 5);
  static const Duration hostApiPromptCooldown = Duration(seconds: 25);

  // ── Socket / API ─────────────────────────────────────────────────────────
  /// Default REST API base URL.
  static const String defaultApiBase = 'https://api.covaone.com/';

  /// Default WebSocket / Socket.IO server base URL.
  static const String defaultWsBase = 'https://sync-c.covaone.com/';
  static const int socketReconnectionAttempts = 3;
  static const int socketReconnectionDelayMs = 1000;

  // ── Misc ─────────────────────────────────────────────────────────────────
  static const String sdkVersion = '1.0.0';
  static const String socketJoinEvent = 'join';
  static const String socketSendMessageEvent = 'send_message';
  static const String socketCallAcceptEvent = 'call_accept';
  static const String socketCallAnswerEvent = 'call_answer';
  static const String socketCallConnectedEvent = 'call_connected';
  static const String socketCallRejectEvent = 'call_reject';
  static const String socketCallEndEvent = 'call_end';
  static const String socketIceCandidateEvent = 'ice_candidate';
  static const String socketPingEvent = 'ping';
  static const String socketPongEvent = 'pong';
  static const String socketCallInviteEvent = 'call_invite';
  static const String socketCallMissedEvent = 'call_missed';

  // ── Voice calls ───────────────────────────────────────────────────────────
  /// Max time to wait for WebRTC to reach "connected" after the answer SDP.
  static const Duration callConnectTimeout = Duration(seconds: 30);

  /// Max time an incoming call may ring before auto-declining.
  static const Duration callRingTimeout = Duration(seconds: 60);
}
