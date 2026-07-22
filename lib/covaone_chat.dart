/// Public entry-point for the `covaone_chat` SDK layer.
///
/// ## Quick-start
/// ```dart
/// // 1. Initialise once in main()
/// await CovaoneChat.init(
///   publicKey: 'your-public-key',
/// );
/// runApp(const MyApp());
///
/// // 2. Place the launcher widget at the root of your widget tree
/// Stack(children: [MaterialApp(...), CovaoneChat.launcher()])
/// ```
library covaone_chat;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'src/blocs/call/call_bloc.dart';
import 'src/blocs/chat/chat_bloc.dart';
import 'src/blocs/session/session_bloc.dart';
import 'src/core/chat_controller.dart';
import 'src/core/config.dart';
import 'src/core/constants.dart';
import 'src/core/di.dart';
import 'src/services/app_api_error_service.dart';
import 'src/services/webrtc_service.dart';
import 'src/services/socket_service.dart';
import 'src/services/audio_service.dart';
import 'src/ui/launcher/covaone_launcher.dart';
import 'src/services/host_http_override_stub.dart'
    if (dart.library.io) 'src/services/host_http_override_io.dart' as host_http;

// ── Public barrel re-exports ──────────────────────────────────────────────────

/// Configuration for the SDK (apiBase, wsBase, publicKey).
export 'src/core/config.dart';

/// Broadcast / announcement data model.
export 'src/data/models/broadcast_model.dart';

/// Call log data model and [CallOutcome] enum.
export 'src/data/models/call_log_model.dart';

/// Widget configuration model received from the server.
export 'src/data/models/configuration_model.dart';

/// FAQ article model.
export 'src/data/models/faq_model.dart';

/// Chat message model and [MessageType] enum.
export 'src/data/models/message_model.dart';

/// Session model.
export 'src/data/models/session_model.dart';

// Blocs — exported so host apps can read state or dispatch events if needed.
export 'src/blocs/session/session_bloc.dart';
export 'src/blocs/chat/chat_bloc.dart';
export 'src/blocs/broadcast/broadcast_bloc.dart';
export 'src/blocs/faq/faq_bloc.dart';

/// [CallBloc], [CallStatus] enum, and all call events.
export 'src/blocs/call/call_bloc.dart';
export 'src/services/app_api_error_service.dart';

// ── Session info ──────────────────────────────────────────────────────────────

/// Lightweight snapshot of the SDK's runtime state, returned by
/// [CovaoneChat.getSessionInfo].
class SessionInfo {
  /// Active conversation / session identifier. `null` before first session.
  final String? sessionId;

  /// Whether [CovaoneChat.init] has completed successfully.
  final bool initialized;

  /// Number of unread messages in the active conversation.
  final int unreadCount;

  /// Name of the tab currently active inside the SDK panel
  /// (`"home"`, `"conversations"`, or `"faq"`).
  final String? currentTab;

  /// Last time the chat / "Send us a Message" screen was opened.
  final DateTime? lastChatOpenedAt;

  const SessionInfo({
    this.sessionId,
    required this.initialized,
    required this.unreadCount,
    this.currentTab,
    this.lastChatOpenedAt,
  });

  @override
  String toString() => 'SessionInfo('
      'sessionId: $sessionId, '
      'initialized: $initialized, '
      'unreadCount: $unreadCount, '
      'currentTab: $currentTab, '
      'lastChatOpenedAt: $lastChatOpenedAt)';
}

// ── CovaoneChat facade ─────────────────────────────────────────────────────────

/// Main SDK facade. Every public member is **static**.
///
/// ## Lifecycle
/// 1. Call [CovaoneChat.init] once, before `runApp`, to register services and
///    kick off the session.
/// 2. Add [CovaoneChat.launcher] as the last child of a root [Stack] so it
///    renders above all other content.
/// 3. Optionally use [open], [close], [toggle] for programmatic control and
///    [onIncomingCall] to hook into call events.
/// 4. Call [destroy] on logout / app teardown to release all resources.
class CovaoneChat {
  CovaoneChat._();

  static bool _initialized = false;
  static void Function(String callId, String agentName)? _incomingCallCallback;
  static AppApiErrorCallback? _appApiErrorCallback;
  static StreamSubscription<SessionState>? _sessionStateSubscription;
  static String? _runtimeUserEmail;
  static String? _runtimeUserFullName;
  static bool _runtimeProfileSyncRequested = false;
  static bool _profileSyncInFlight = false;

  // ── SDK version ───────────────────────────────────────────────────────────

  /// Current semantic version of the SDK.
  static String get version => CovaoneConstants.sdkVersion;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Initialises all SDK services and begins the session lifecycle.
  ///
  /// Must be called **once** before any UI interaction, typically in `main()`
  /// after [WidgetsFlutterBinding.ensureInitialized].
  ///
  /// Optionally pass [userEmail] and [userFullName] when the host app already
  /// knows the end-user's identity. When both are valid, the SDK skips the
  /// in-chat lead-capture form and registers the profile automatically the
  /// first time the user opens a conversation.
  ///
  /// Returning users load a cached session on startup (no REST call) and connect
  /// the WebSocket immediately so inbound calls/messages can arrive. Session data
  /// is refreshed from the API when its TTL expires ([sessionCacheTtl], default
  /// 24 hours) and the user opens the support panel. Broadcasts hydrate from
  /// cache while the panel is closed ([broadcastCacheTtl]) and always refresh
  /// from the API when the panel opens.
  ///
  /// You can also provide identity later via [setUserProfile] +
  /// [syncUserProfile] (or [pushUserProfile]).
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await CovaoneChat.init(
  ///     publicKey: 'your-public-key',
  ///     // apiBase defaults to https://api.covaone.com/
  ///     // wsBase defaults to https://sync-c.covaone.com/
  ///     userEmail: 'user@example.com',      // optional
  ///     userFullName: 'Jane Doe',           // optional
  ///     autoIntercept: true,                // optional, default true
  ///     helpCardPosition: CovaoneHelpCardPosition.top, // optional
  ///     helpCardColor: Color(0xFF1A1A1A),             // optional
  ///     helpCardDisplayDuration: Duration(seconds: 5), // optional
  ///   );
  ///   runApp(const MyApp());
  /// }
  /// ```
  static Future<void> init({
    required String publicKey,
    String apiBase = CovaoneConstants.defaultApiBase,
    String wsBase = CovaoneConstants.defaultWsBase,
    String? userEmail,
    String? userFullName,
    bool autoIntercept = true,
    @Deprecated('Use autoIntercept instead.')
    bool? enableAutomaticGlobalInterception,
    CovaoneHelpCardPosition helpCardPosition = CovaoneHelpCardPosition.top,
    Color? helpCardColor,
    Duration helpCardDisplayDuration =
        CovaoneConstants.hostApiPromptDisplayDuration,
    Duration sessionCacheTtl = CovaoneConstants.defaultSessionCacheTtl,
    Duration broadcastCacheTtl = CovaoneConstants.defaultBroadcastCacheTtl,
  }) async {
    if (_initialized) return;

    final config = CovaoneConfig(
      publicKey: publicKey,
      apiBase: apiBase,
      wsBase: wsBase,
      userEmail: userEmail,
      userFullName: userFullName,
      helpCardPosition: helpCardPosition,
      helpCardColor: helpCardColor,
      helpCardDisplayDuration: helpCardDisplayDuration,
      sessionCacheTtl: sessionCacheTtl,
      broadcastCacheTtl: broadcastCacheTtl,
    );

    await CovaoneDI.setup(config);

    final appApiErrorService = CovaoneDI.sl<AppApiErrorService>();
    appApiErrorService.setOnErrorCallback(_appApiErrorCallback);

    final interceptEnabled = enableAutomaticGlobalInterception ?? autoIntercept;
    if (interceptEnabled) {
      host_http.installHostHttpMonitoring(
        service: appApiErrorService,
        sdkApiBaseUri: Uri.parse(config.apiBase),
      );
    }

    // Wire any pre-registered incoming-call callback.
    if (_incomingCallCallback != null) {
      CovaoneDI.sl<CallBloc>().onIncomingCallCallback = _incomingCallCallback;
    }

    // Keep a lightweight observer so runtime profile sync can happen as soon
    // as the session transitions into a profile-accepting state.
    await _sessionStateSubscription?.cancel();
    _sessionStateSubscription = CovaoneDI.sl<SessionBloc>().stream.listen((s) {
      if (s is SessionSettingProfile) {
        _profileSyncInFlight = true;
        return;
      }
      if (_profileSyncInFlight) {
        _profileSyncInFlight = false;
      }
      unawaited(_syncUserProfileIfPossible());
    });

    // Kick off session initialisation (loads stored session or creates one).
    CovaoneDI.sl<SessionBloc>()
        .add(CovaoneInitializeEvent(publicKey: publicKey));

    _initialized = true;
    unawaited(_syncUserProfileIfPossible());
  }

  // ── Launcher widget ───────────────────────────────────────────────────────

  /// Returns the SDK overlay widget.
  ///
  /// Insert as the **last child** of a [Stack] wrapping your [MaterialApp] so
  /// the FAB and chat panel render above all other content:
  ///
  /// ```dart
  /// Stack(
  ///   children: [
  ///     MaterialApp(...),
  ///     CovaoneChat.launcher(),
  ///   ],
  /// )
  /// ```
  static Widget launcher() {
    assert(_initialized,
        'Call CovaoneChat.init() before inserting the launcher widget.');
    return const CovaoneLauncher();
  }

  /// Backward-compatible helper retained for apps already calling it.
  ///
  /// Automatic host-HTTP monitoring is now installed globally during [init],
  /// so this method simply executes [body].
  static T runWithAutomaticGlobalInterception<T>(T Function() body) {
    if (!_initialized) {
      throw StateError(
          'Call CovaoneChat.init() before runWithAutomaticGlobalInterception().');
    }
    return host_http.runWithHostHttpMonitoring(body);
  }

  // ── Programmatic panel control ────────────────────────────────────────────

  /// Opens the chat panel programmatically.
  static void open() => CovaoneChatController.open();

  /// Closes the chat panel programmatically.
  static void close() => CovaoneChatController.close();

  /// Toggles the chat panel open/closed.
  static void toggle() => CovaoneChatController.toggle();

  // ── Resource teardown ─────────────────────────────────────────────────────

  /// Tears down all SDK resources and resets the service locator.
  ///
  /// Safe to call on user logout. After calling [destroy], you must call
  /// [init] again before using the SDK.
  static Future<void> destroy() async {
    if (!_initialized) return;
    CovaoneChatController.close();
    await _sessionStateSubscription?.cancel();
    _sessionStateSubscription = null;
    host_http.uninstallHostHttpMonitoring();
    if (CovaoneDI.sl.isRegistered<WebRtcService>()) {
      await CovaoneDI.sl<WebRtcService>()
          .teardown(callId: '', room: '', endReason: 'destroyed');
    }
    if (CovaoneDI.sl.isRegistered<SocketService>()) {
      CovaoneDI.sl<SocketService>().disconnect();
    }
    if (CovaoneDI.sl.isRegistered<AudioService>()) {
      await CovaoneDI.sl<AudioService>().dispose();
    }
    await CovaoneDI.reset();
    _initialized = false;
    _incomingCallCallback = null;
    _appApiErrorCallback = null;
    _runtimeUserEmail = null;
    _runtimeUserFullName = null;
    _runtimeProfileSyncRequested = false;
    _profileSyncInFlight = false;
  }

  // ── Call callbacks ────────────────────────────────────────────────────────

  /// Registers a callback that fires whenever an incoming call arrives.
  ///
  /// If [init] has already been called the callback is wired immediately;
  /// otherwise it is stored and applied during the next [init] call.
  ///
  /// ```dart
  /// CovaoneChat.onIncomingCall((callId, agentName) {
  ///   print('Incoming call from $agentName (id: $callId)');
  /// });
  /// ```
  static void onIncomingCall(
      void Function(String callId, String agentName) callback) {
    _incomingCallCallback = callback;
    if (_initialized) {
      CovaoneDI.sl<CallBloc>().onIncomingCallCallback = callback;
    }
  }

  /// Programmatically ends the currently active call.
  static void endCall() {
    if (!_initialized) return;
    CovaoneDI.sl<CallBloc>().add(const HangupCallEvent());
  }

  /// Assigns host-user identity at runtime.
  ///
  /// Call [syncUserProfile] afterwards to push this identity to the active
  /// SDK session. Use [pushUserProfile] for one-step assign + sync.
  static void setUserProfile({
    required String email,
    required String fullName,
  }) {
    _runtimeUserEmail = email.trim();
    _runtimeUserFullName = fullName.trim();
  }

  /// Pushes previously assigned runtime identity to the active SDK session.
  ///
  /// Behaviour when a session is already loaded:
  /// - Same email already on the session → no-op (name changes are ignored).
  /// - Different email → starts a fresh session, then calls `set-profile`.
  /// - No email yet → calls `set-profile` on the current session.
  ///
  /// If the session is not ready yet, sync is queued and auto-runs once the
  /// session reaches a profile-accepting state.
  static Future<void> syncUserProfile() async {
    if (_runtimeUserEmail == null || _runtimeUserFullName == null) {
      throw StateError(
          'No runtime profile set. Call setUserProfile(...) first.');
    }
    if (!_isValidRuntimeProfile(_runtimeUserEmail!, _runtimeUserFullName!)) {
      throw ArgumentError(
          'Invalid runtime profile. Ensure valid email and fullName length >= 4.');
    }
    _runtimeProfileSyncRequested = true;
    await _syncUserProfileIfPossible();
  }

  /// One-step helper: assign runtime identity then sync immediately.
  static Future<void> pushUserProfile({
    required String email,
    required String fullName,
  }) async {
    setUserProfile(email: email, fullName: fullName);
    await syncUserProfile();
  }

  /// Alias for [pushUserProfile] to match concise host-app semantics.
  static Future<void> push({
    required String email,
    required String fullName,
  }) async {
    await pushUserProfile(email: email, fullName: fullName);
  }

  /// Alias for [syncUserProfile] to match concise host-app semantics.
  static Future<void> sync() async {
    await syncUserProfile();
  }

  // ── Host-app API monitoring ───────────────────────────────────────────────

  /// Registers a callback that receives host-app API errors captured by any
  /// integration path: automatic global interception, attached Dio interceptor,
  /// or explicit [reportAppApiError].
  static void onAppApiError(AppApiErrorCallback callback) {
    _appApiErrorCallback = callback;
    if (_initialized && CovaoneDI.sl.isRegistered<AppApiErrorService>()) {
      CovaoneDI.sl<AppApiErrorService>().setOnErrorCallback(callback);
    }
  }

  /// Attaches the SDK interceptor to a host-app [Dio] instance.
  ///
  /// Safe to call multiple times for the same instance; duplicates are ignored.
  static void attachHostDioInterceptor(Dio dio) {
    final alreadyAttached =
        dio.interceptors.any((i) => i is HostAppApiDioInterceptor);
    if (alreadyAttached) return;

    if (!_initialized || !CovaoneDI.sl.isRegistered<AppApiErrorService>()) {
      throw StateError(
          'Call CovaoneChat.init() before attaching interceptors.');
    }

    dio.interceptors.add(
      HostAppApiDioInterceptor(service: CovaoneDI.sl<AppApiErrorService>()),
    );
  }

  /// Explicitly reports a host-app API error to the SDK.
  ///
  /// Use this when the app has a non-Dio/non-http transport or custom handling.
  static void reportAppApiError({
    int? statusCode,
    Uri? uri,
    String method = 'UNKNOWN',
    String? message,
  }) {
    if (!_initialized || !CovaoneDI.sl.isRegistered<AppApiErrorService>()) {
      return;
    }

    CovaoneDI.sl<AppApiErrorService>().report(
      AppApiErrorEvent(
        source: AppApiErrorSource.manualReport,
        method: method.toUpperCase(),
        uri: uri,
        statusCode: statusCode,
        message: message,
        timestamp: DateTime.now(),
      ),
    );
  }

  static Future<void> _syncUserProfileIfPossible() async {
    if (!_initialized) return;
    if (!_runtimeProfileSyncRequested) return;
    if (_profileSyncInFlight) return;
    if (!CovaoneDI.sl.isRegistered<SessionBloc>()) return;

    final email = _runtimeUserEmail?.trim();
    final fullName = _runtimeUserFullName?.trim();
    if (email == null || fullName == null) return;
    if (!_isValidRuntimeProfile(email, fullName)) return;

    final sessionBloc = CovaoneDI.sl<SessionBloc>();
    final state = sessionBloc.state;
    if (state is SessionInitial ||
        state is SessionLoading ||
        state is SessionSettingProfile ||
        state is SessionError) {
      return;
    }

    if (state is SessionLoaded) {
      final existingEmail = state.session.email?.trim();
      if (existingEmail != null && existingEmail.isNotEmpty) {
        if (existingEmail.toLowerCase() == email.toLowerCase()) {
          // Same identity already on this session — skip set-profile.
          _runtimeProfileSyncRequested = false;
          return;
        }

        // Different user on this device — wipe session and retry set-profile
        // once the fresh session reaches SessionProfileFormVisible.
        _profileSyncInFlight = true;
        sessionBloc.add(const NewConversationEvent());
        return;
      }
    }

    if (state is! SessionProfileFormVisible && state is! SessionLoaded) {
      return;
    }

    _runtimeProfileSyncRequested = false;
    _profileSyncInFlight = true;
    sessionBloc.add(SetProfileEvent(email: email, name: fullName));
  }

  static bool _isValidRuntimeProfile(String email, String fullName) {
    if (fullName.trim().length < 4) return false;
    return email.contains('@') && email.contains('.');
  }

  // ── Session info ──────────────────────────────────────────────────────────

  /// Returns a lightweight snapshot of the SDK's current runtime state.
  static SessionInfo getSessionInfo() {
    if (!_initialized) {
      return const SessionInfo(
          sessionId: null, initialized: false, unreadCount: 0);
    }

    final sessionBloc = CovaoneDI.sl<SessionBloc>();
    final chatBloc = CovaoneDI.sl<ChatBloc>();

    return SessionInfo(
      sessionId: sessionBloc.currentSessionId,
      initialized: sessionBloc.state is SessionLoaded,
      unreadCount: chatBloc.unreadCount,
      currentTab: chatBloc.state.currentTab.name,
      lastChatOpenedAt: chatBloc.state.lastChatOpenedAt,
    );
  }
}
