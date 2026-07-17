import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/constants.dart';
import '../data/models/message_model.dart';

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

  // ── Stream controllers ────────────────────────────────────────────────────

  final _messagesCtrl =
      StreamController<MessageModel>.broadcast();
  final _callInvitesCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  final _iceCandidateCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  final _callEndedCtrl =
      StreamController<Map<String, dynamic>>.broadcast();

  // ── Public streams ────────────────────────────────────────────────────────

  Stream<MessageModel> get incomingMessages => _messagesCtrl.stream;
  Stream<Map<String, dynamic>> get callInvites => _callInvitesCtrl.stream;
  Stream<Map<String, dynamic>> get iceCandidate => _iceCandidateCtrl.stream;
  Stream<Map<String, dynamic>> get callEnded => _callEndedCtrl.stream;

  bool get isConnected => _socket?.connected ?? false;

  // ── Connection lifecycle ──────────────────────────────────────────────────

  void connect(String wsBase, String sessionId) {
    if (_socket != null && _socket!.connected) {
      _emitJoin(sessionId);
      return;
    }

    _socket = io.io(
      wsBase,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(CovaoneConstants.socketReconnectionAttempts)
          .setReconnectionDelay(
              CovaoneConstants.socketReconnectionDelayMs)
          .build(),
    );

    _socket!
      ..on('connect', (_) {
        debugPrint('[Covaone Socket] connected');
        _emitJoin(sessionId);
      })
      ..on('disconnect', (_) {
        debugPrint('[Covaone Socket] disconnected');
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
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Re-joins an existing socket connection with a (possibly new) session ID.
  void reconnect(String sessionId) {
    if (_socket == null || !_socket!.connected) return;
    _emitJoin(sessionId);
  }

  // ── Outbound events ───────────────────────────────────────────────────────

  void sendMessage(String sessionId, String text) {
    _socket?.emit(CovaoneConstants.socketSendMessageEvent, {
      'room': sessionId,
      'messageData': {
        'origin': 'frontend',
        'message': text,
        'message_type': MessageType.QUERY.value,
        'file': null,
      },
    });
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
      debugPrint('[Covaone Socket] send_message parse error: $e');
    }
  }

  void _onCallInvite(dynamic data) {
    try {
      _callInvitesCtrl.add(_toMap(data));
    } catch (e) {
      debugPrint('[Covaone Socket] call_invite parse error: $e');
    }
  }

  void _onIceCandidate(dynamic data) {
    try {
      _iceCandidateCtrl.add(_toMap(data));
    } catch (e) {
      debugPrint('[Covaone Socket] ice_candidate parse error: $e');
    }
  }

  void _onCallEnded(dynamic data) {
    try {
      _callEndedCtrl.add(_toMap(data));
    } catch (e) {
      debugPrint('[Covaone Socket] call_end parse error: $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _emitJoin(String sessionId) {
    _socket?.emit(CovaoneConstants.socketJoinEvent, sessionId);
    debugPrint('[Covaone Socket] joined room $sessionId');
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw FormatException('Unexpected socket payload type: ${data.runtimeType}');
  }

  void dispose() {
    disconnect();
    _messagesCtrl.close();
    _callInvitesCtrl.close();
    _iceCandidateCtrl.close();
    _callEndedCtrl.close();
  }
}
