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

  factory SendMessageAck.fromResponse(dynamic response) {
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final status = map['status']?.toString().toLowerCase();
      return SendMessageAck(
        ok: status == 'ok',
        clientMessageId: map['client_message_id']?.toString() ??
            map['clientMessageId']?.toString(),
        error: map['error']?.toString(),
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
class SocketService {
  io.Socket? _socket;
  String? _wsBase;
  String? _sessionId;

  /// Completes when the current connect attempt succeeds.
  Completer<void>? _connectCompleter;

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

  // ── Connection lifecycle ──────────────────────────────────────────────────

  void connect(String wsBase, String sessionId) {
    _wsBase = wsBase;
    _sessionId = sessionId;

    if (_socket != null && _socket!.connected) {
      _emitJoin(sessionId);
      _completeConnect();
      return;
    }

    // In-flight connect: keep the existing socket; join will use [_sessionId].
    if (_socket != null &&
        _connectCompleter != null &&
        !_connectCompleter!.isCompleted) {
      return;
    }

    // Dead / exhausted socket — tear down before opening a fresh connection.
    if (_socket != null) {
      _tearDownSocket();
    }

    _connectCompleter = Completer<void>();

    _socket = io.io(
      wsBase,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableForceNew()
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(CovaoneConstants.socketReconnectionAttempts)
          .setReconnectionDelay(CovaoneConstants.socketReconnectionDelayMs)
          .build(),
    );

    _socket!
      ..on('connect', (_) {
        // debugPrint('[Covaone Socket] connected');
        final id = _sessionId;
        if (id != null) _emitJoin(id);
        _completeConnect();
      })
      ..on('disconnect', (_) {
        // debugPrint('[Covaone Socket] disconnected');
      })
      // Manager-level: attempts exhausted without ever connecting leaves a
      // zombie socket + incomplete completer unless we complete here.
      ..onReconnectFailed((_) {
        final completer = _connectCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(StateError('reconnect_failed'));
        }
      })
      ..on(CovaoneConstants.socketSendMessageEvent, _onMessage)
      ..on(CovaoneConstants.socketCallInviteEvent, _onCallInvite)
      ..on(CovaoneConstants.socketIceCandidateEvent, _onIceCandidate)
      ..on(CovaoneConstants.socketCallEndEvent, _onCallEnded)
      ..on(CovaoneConstants.socketCallMissedEvent, _onCallEnded)
      ..on(CovaoneConstants.socketPongEvent, (_) {
        _socket?.emit(CovaoneConstants.socketPingEvent);
      });
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
  Future<bool> ensureConnected(
    String wsBase,
    String sessionId, {
    Duration? timeout,
  }) async {
    _wsBase = wsBase;
    _sessionId = sessionId;

    if (isConnected) {
      _emitJoin(sessionId);
      return true;
    }

    connect(wsBase, sessionId);
    final wait = timeout ?? CovaoneConstants.socketConnectWaitTimeout;
    var ready = await waitUntilConnected(timeout: wait);
    if (ready) return true;

    // Break zombie in-flight / exhausted-reconnect state and try once more.
    return _forceReconnectAndWait(wsBase, sessionId, timeout: wait);
  }

  /// Waits for an in-flight [connect] to succeed, or returns immediately if
  /// already connected / nothing is connecting.
  Future<bool> waitUntilConnected({Duration? timeout}) async {
    if (isConnected) return true;

    final completer = _connectCompleter;
    if (completer == null || completer.isCompleted) {
      return false;
    }

    try {
      await completer.future.timeout(
        timeout ?? CovaoneConstants.socketConnectWaitTimeout,
      );
      return isConnected;
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
  /// If the socket is still connecting (typical for the first message after
  /// profile setup), waits up to [CovaoneConstants.socketConnectWaitTimeout]
  /// and will force a reconnect when a prior connection died.
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

    if (!isConnected) {
      var ready = await waitUntilConnected();
      if (!ready && _wsBase != null) {
        ready = await _forceReconnectAndWait(_wsBase!, sessionId);
      }
      if (!ready) {
        return SendMessageAck.failed('not_connected');
      }
    }

    final socket = _socket;
    if (socket == null || !socket.connected) {
      return SendMessageAck.failed('not_connected');
    }

    // Ordered with send on the same connection so the room is joined first.
    _emitJoin(sessionId);

    final completer = Completer<SendMessageAck>();
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
          completer.complete(SendMessageAck.fromResponse(response));
        }
      },
    );

    try {
      return await completer.future.timeout(
        CovaoneConstants.socketSendAckTimeout,
        onTimeout: () => SendMessageAck.failed('timeout'),
      );
    } catch (e) {
      return SendMessageAck.failed(e.toString());
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
    _tearDownSocket();
    connect(wsBase, sessionId);
    return waitUntilConnected(
      timeout: timeout ?? CovaoneConstants.socketConnectWaitTimeout,
    );
  }

  void _emitJoin(String sessionId) {
    _socket?.emit(CovaoneConstants.socketJoinEvent, sessionId);
    // debugPrint('[Covaone Socket] joined room $sessionId');
  }

  void _completeConnect() {
    final completer = _connectCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _tearDownSocket() {
    final socket = _socket;
    _socket = null;
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
