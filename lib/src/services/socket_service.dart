import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/constants.dart';
import '../data/models/message_error_info.dart';
import '../data/models/message_model.dart';

/// Result of a Socket.IO `send_message` acknowledgement.
class SendMessageAck {
  final bool ok;
  final String? clientMessageId;
  final String? error;

  const SendMessageAck({
    required this.ok,
    this.clientMessageId,
    this.error,
  });

  factory SendMessageAck.fromResponse(
    dynamic response, {
    String? expectedClientMessageId,
  }) {
    // socket_io_client may deliver multi-arg acks as a List.
    if (response is List) {
      if (response.isEmpty) {
        return const SendMessageAck(ok: false, error: 'empty_ack');
      }
      return SendMessageAck.fromResponse(
        response.first,
        expectedClientMessageId: expectedClientMessageId,
      );
    }
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final status = map['status']?.toString().toLowerCase();
      final clientMessageId = map['client_message_id']?.toString() ??
          map['clientMessageId']?.toString();
      // Strict: only an explicit ok status counts as delivered. A bare map
      // (or message echo) must not mark the bubble as sent.
      var ok = status == 'ok';
      // When the server echoes the client id, require a match so a stale /
      // mismatched ack cannot mark the wrong bubble as sent.
      if (ok &&
          expectedClientMessageId != null &&
          clientMessageId != null &&
          clientMessageId != expectedClientMessageId) {
        ok = false;
      }
      return SendMessageAck(
        ok: ok,
        clientMessageId: clientMessageId,
        error: ok ? null : (map['error']?.toString() ?? 'nack'),
      );
    }
    // Some servers ack with a bare string / bool.
    if (response == true || response == 'ok') {
      return const SendMessageAck(ok: true);
    }
    return const SendMessageAck(ok: false, error: 'unexpected_ack');
  }

  factory SendMessageAck.failed(String error) =>
      SendMessageAck(ok: false, error: error);
}

/// Manages the Socket.IO connection to the Covaone real-time server.
///
/// The service exposes typed [Stream]s for each category of inbound event
/// and provides imperative emit helpers for outbound events. The host BLoCs
/// subscribe to these streams; they never interact with the raw socket.
///
/// **Platform note:** `flutter_webrtc` handles in-call audio/video natively;
/// the socket only carries signalling (SDP, ICE candidates).
///
/// **Android note:** the OS / radio can silently kill the TCP connection while
/// the client still reports [isConnected]. Callers should prefer
/// [ensureConnected] with `force: true` after resume, and [sendMessage] will
/// probe / refresh a stale socket before emitting.
class SocketService {
  io.Socket? _socket;
  String? _wsBase;
  String? _sessionId;

  /// Completes when the current connect attempt succeeds.
  Completer<void>? _connectCompleter;

  /// Set on disconnect / send timeout so the next ensure/send refreshes the
  /// socket instead of trusting a zombie `connected == true` state.
  bool _needsReconnect = false;

  /// Last time we observed a healthy socket (connect or successful send ACK).
  DateTime? _lastHealthyAt;

  /// In-flight send ACK completers — failed immediately on disconnect.
  final Set<Completer<SendMessageAck>> _pendingSendAcks = {};

  // ── Stream controllers ────────────────────────────────────────────────────

  final _messagesCtrl = StreamController<MessageModel>.broadcast();
  final _callInvitesCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _iceCandidateCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _callEndedCtrl = StreamController<Map<String, dynamic>>.broadcast();

  // ── Public streams ────────────────────────────────────────────────────────

  Stream<MessageModel> get incomingMessages => _messagesCtrl.stream;
  Stream<Map<String, dynamic>> get callInvites => _callInvitesCtrl.stream;
  Stream<Map<String, dynamic>> get iceCandidate => _iceCandidateCtrl.stream;
  Stream<Map<String, dynamic>> get callEnded => _callEndedCtrl.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Last ws base / session used for [connect]. Useful for resume reconnect.
  String? get wsBase => _wsBase;
  String? get sessionId => _sessionId;

  bool get _isStale {
    if (_needsReconnect) return true;
    if (!isConnected) return true;
    final last = _lastHealthyAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >
        CovaoneConstants.socketStaleAfter;
  }

  // ── Connection lifecycle ──────────────────────────────────────────────────

  void connect(String wsBase, String sessionId) {
    _wsBase = wsBase;
    _sessionId = sessionId;

    if (_socket != null && _socket!.connected && !_needsReconnect) {
      _emitJoin(sessionId);
      _completeConnect();
      return;
    }

    // In-flight connect: keep the existing socket; join will use [_sessionId].
    if (_socket != null &&
        !_needsReconnect &&
        _connectCompleter != null &&
        !_connectCompleter!.isCompleted) {
      return;
    }

    // Dead / exhausted / stale socket — tear down before opening a fresh one.
    if (_socket != null) {
      _tearDownSocket();
    }

    _connectCompleter = Completer<void>();
    _needsReconnect = false;

    // Flutter mobile only supports the websocket transport (polling/XHR is not
    // reliable on dart:io). Mixing in polling produces half-dead connections
    // that still report `connected` while emits never reach the server.
    _socket = io.io(
      wsBase,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(CovaoneConstants.socketReconnectionAttempts)
          .setReconnectionDelay(CovaoneConstants.socketReconnectionDelayMs)
          .build(),
    );

    _socket!
      ..on('connect', (_) {
        _needsReconnect = false;
        _lastHealthyAt = DateTime.now();
        final id = _sessionId;
        if (id != null) _emitJoin(id);
        _completeConnect();
      })
      ..on('disconnect', (_) {
        _needsReconnect = true;
        _failPendingSends('disconnected');
      })
      ..on('connect_error', (_) {
        _needsReconnect = true;
      })
      // Manager-level: attempts exhausted without ever connecting leaves a
      // zombie socket + incomplete completer unless we complete here.
      ..onReconnectFailed((_) {
        _needsReconnect = true;
        final completer = _connectCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(StateError('reconnect_failed'));
        }
      })
      ..on(CovaoneConstants.socketSendMessageEvent, _onMessage)
      ..on(CovaoneConstants.socketCallInviteEvent, _onCallInvite)
      ..on(CovaoneConstants.socketIceCandidateEvent, _onIceCandidate)
      ..on(CovaoneConstants.socketCallEndEvent, _onCallEnded)
      ..on(CovaoneConstants.socketCallMissedEvent, _onCallEnded);
  }

  void disconnect() {
    _tearDownSocket();
    _wsBase = null;
    _sessionId = null;
  }

  /// Ensures a live connection for [sessionId], reconnecting when needed.
  ///
  /// Prefer this over [reconnect] from UI/lifecycle paths — it actually opens
  /// a new socket when the previous one is dead (e.g. after backgrounding).
  ///
  /// Pass [force] after app resume / network changes so a zombie
  /// `connected == true` socket is torn down and replaced.
  Future<bool> ensureConnected(
    String wsBase,
    String sessionId, {
    Duration? timeout,
    bool force = false,
  }) async {
    _wsBase = wsBase;
    _sessionId = sessionId;

    final wait = timeout ?? CovaoneConstants.socketConnectWaitTimeout;

    // Healthy live socket — just ensure we are in the room.
    if (!force && isConnected && !_needsReconnect && !_isStale) {
      _emitJoin(sessionId);
      return true;
    }

    // Zombie / explicit refresh: tear down and open a new transport.
    if (force || (isConnected && (_needsReconnect || _isStale))) {
      return _forceReconnectAndWait(wsBase, sessionId, timeout: wait);
    }

    // Not connected — prefer waiting on an in-flight connect (first message
    // after profile setup) before tearing anything down.
    connect(wsBase, sessionId);
    var ready = await waitUntilConnected(timeout: wait);
    if (ready) return true;

    return _forceReconnectAndWait(wsBase, sessionId, timeout: wait);
  }

  /// Waits for an in-flight [connect] to succeed, or returns immediately if
  /// already connected / nothing is connecting.
  Future<bool> waitUntilConnected({Duration? timeout}) async {
    if (isConnected && !_needsReconnect) return true;

    final completer = _connectCompleter;
    if (completer == null || completer.isCompleted) {
      return isConnected && !_needsReconnect;
    }

    try {
      await completer.future.timeout(
        timeout ?? CovaoneConstants.socketConnectWaitTimeout,
      );
      return isConnected && !_needsReconnect;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Re-joins when already connected; otherwise opens a new connection using
  /// the last known [wsBase].
  ///
  /// Prefer [ensureConnected] when the ws base is available from config.
  void reconnect(String sessionId) {
    final base = _wsBase;
    if (base == null) {
      // Cannot open a socket without a base URL; join-only when live.
      if (isConnected) _emitJoin(sessionId);
      return;
    }
    connect(base, sessionId);
  }

  // ── Outbound events ───────────────────────────────────────────────────────

  /// Emits `send_message` and waits for a Socket.IO acknowledgement.
  ///
  /// Refreshes a stale/zombie socket before emitting. On ACK timeout or
  /// disconnect mid-send, forces one reconnect and retries once so the user
  /// does not need to kill the host app.
  ///
  /// Returns [SendMessageAck.failed] when the socket cannot be made ready or
  /// the server does not ACK within [CovaoneConstants.socketSendAckTimeout].
  Future<SendMessageAck> sendMessage(
    String sessionId,
    String text, {
    required String clientMessageId,
    MessageErrorInfo? errorInfo,
  }) async {
    _sessionId = sessionId;

    // Only force-refresh when the client *thinks* it is connected but the
    // transport is likely dead. If we are simply mid-connect, wait instead.
    final forceRefresh =
        _needsReconnect || (isConnected && _isStale);
    final first = await _sendMessageOnce(
      sessionId,
      text,
      clientMessageId: clientMessageId,
      errorInfo: errorInfo,
      forceRefresh: forceRefresh,
    );
    if (first.ok) return first;

    // Timeout / disconnect / nack often means a zombie transport on Android.
    // Tear down, reconnect, and retry once with the same clientMessageId.
    if (_wsBase == null) return first;

    final retryable = first.error == 'timeout' ||
        first.error == 'not_connected' ||
        first.error == 'disconnected' ||
        first.error == 'socket_gone';
    if (!retryable) return first;

    final second = await _sendMessageOnce(
      sessionId,
      text,
      clientMessageId: clientMessageId,
      errorInfo: errorInfo,
      forceRefresh: true,
    );
    return second;
  }

  Future<SendMessageAck> _sendMessageOnce(
    String sessionId,
    String text, {
    required String clientMessageId,
    MessageErrorInfo? errorInfo,
    required bool forceRefresh,
  }) async {
    final base = _wsBase;
    if (base == null) {
      return SendMessageAck.failed('not_connected');
    }

    final ready = await ensureConnected(
      base,
      sessionId,
      force: forceRefresh,
    );
    if (!ready) {
      return SendMessageAck.failed('not_connected');
    }

    final socket = _socket;
    if (socket == null || !socket.connected) {
      _needsReconnect = true;
      return SendMessageAck.failed('not_connected');
    }

    // Ordered with send on the same connection so the room is joined first.
    _emitJoin(sessionId);

    final completer = Completer<SendMessageAck>();
    _pendingSendAcks.add(completer);

    try {
      socket.emitWithAck(
        CovaoneConstants.socketSendMessageEvent,
        {
          'room': sessionId,
          'messageData': {
            'origin': 'frontend',
            'message': text,
            'message_type': MessageType.QUERY.value,
            'file': null,
            'client_message_id': clientMessageId,
            'error-info': errorInfo?.toJson(),
          },
        },
        ack: (dynamic response) {
          if (!completer.isCompleted) {
            completer.complete(SendMessageAck.fromResponse(
              response,
              expectedClientMessageId: clientMessageId,
            ));
          }
        },
      );

      final ack = await completer.future.timeout(
        CovaoneConstants.socketSendAckTimeout,
        onTimeout: () => SendMessageAck.failed('timeout'),
      );

      if (ack.ok) {
        _lastHealthyAt = DateTime.now();
        _needsReconnect = false;
      } else if (ack.error == 'timeout') {
        // Likely a zombie socket — do not trust `connected` on the next attempt.
        _needsReconnect = true;
      }
      return ack;
    } catch (e) {
      return SendMessageAck.failed(e.toString());
    } finally {
      _pendingSendAcks.remove(completer);
    }
  }

  /// Generic emit for call-signalling events (accept, answer, reject, end,
  /// ice_candidate). Payload is merged with standard customer fields by the
  /// caller (e.g. [CallBloc]).
  void emitCallEvent(String event, Map<String, dynamic> payload) {
    _socket?.emit(event, payload);
  }

  // ── Inbound handlers ──────────────────────────────────────────────────────

  void _onMessage(dynamic data) {
    try {
      final raw = _toMap(data);
      final messageData = raw['messageData'] as Map<String, dynamic>? ?? raw;
      final model = MessageModel.fromJson(messageData);
      _lastHealthyAt = DateTime.now();
      _messagesCtrl.add(model);
    } catch (e) {
      // debugPrint('[Covaone Socket] send_message parse error: $e');
    }
  }

  void _onCallInvite(dynamic data) {
    try {
      _callInvitesCtrl.add(_toMap(data));
    } catch (e) {
      // debugPrint('[Covaone Socket] call_invite parse error: $e');
    }
  }

  void _onIceCandidate(dynamic data) {
    try {
      _iceCandidateCtrl.add(_toMap(data));
    } catch (e) {
      // debugPrint('[Covaone Socket] ice_candidate parse error: $e');
    }
  }

  void _onCallEnded(dynamic data) {
    try {
      _callEndedCtrl.add(_toMap(data));
    } catch (e) {
      // debugPrint('[Covaone Socket] call_end parse error: $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<bool> _forceReconnectAndWait(
    String wsBase,
    String sessionId, {
    Duration? timeout,
  }) async {
    _needsReconnect = true;
    _tearDownSocket();
    connect(wsBase, sessionId);
    return waitUntilConnected(
      timeout: timeout ?? CovaoneConstants.socketConnectWaitTimeout,
    );
  }

  void _emitJoin(String sessionId) {
    _socket?.emit(CovaoneConstants.socketJoinEvent, sessionId);
  }

  void _completeConnect() {
    final completer = _connectCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _failPendingSends(String error) {
    final pending = List<Completer<SendMessageAck>>.from(_pendingSendAcks);
    _pendingSendAcks.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.complete(SendMessageAck.failed(error));
      }
    }
  }

  void _tearDownSocket() {
    final socket = _socket;
    _socket = null;
    _failPendingSends('socket_gone');
    try {
      socket?.disconnect();
      socket?.dispose();
    } catch (_) {
      // Ignore dispose races during reconnect.
    }
    final completer = _connectCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(StateError('socket_torn_down'));
    }
    _connectCompleter = null;
    _needsReconnect = true;
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw FormatException(
        'Unexpected socket payload type: ${data.runtimeType}');
  }

  void dispose() {
    disconnect();
    _messagesCtrl.close();
    _callInvitesCtrl.close();
    _iceCandidateCtrl.close();
    _callEndedCtrl.close();
  }
}
