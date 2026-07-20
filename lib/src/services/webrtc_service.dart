import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/constants.dart';
import 'socket_service.dart';
import 'turn_ice_service.dart';

/// Manages the WebRTC peer connection for voice calls.
///
/// Instantiated once via [CovaoneDI] and injected into [CallBloc].
/// All peer-connection setup, SDP exchange, and media track management are
/// contained here so that [CallBloc] remains focused on UI state only.
class WebRtcService {
  final SocketService _socketService;
  final TurnIceService _turnIceService;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  /// Remote ICE candidates that arrived before the peer connection and/or
  /// [setRemoteDescription] completed. Flushed once both are ready.
  final List<Map<String, dynamic>> _iceCandidateBuffer = [];
  bool _remoteDescriptionSet = false;
  bool _connectionResolved = false;

  WebRtcService({
    required SocketService socketService,
    required TurnIceService turnIceService,
  })  : _socketService = socketService,
        _turnIceService = turnIceService;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Warms TURN credentials during ringing so accept can start faster.
  void prefetchTurnCredentials() => _turnIceService.prefetch();

  /// Accepts an incoming call.
  ///
  /// Steps (per signalling contract):
  /// 1. Emit `call_accept` immediately (tells dashboard we are connecting).
  /// 2. Fetch TURN/STUN iceServers in parallel with microphone access.
  /// 3. Create RTCPeerConnection with fetched iceServers.
  /// 4. Set the agent's remote SDP offer; flush any buffered ICE candidates.
  /// 5. Create SDP answer, set as local description.
  /// 6. Emit `call_answer` with the answer SDP.
  ///
  /// [onIceCandidate] is called for each local ICE candidate to be forwarded.
  /// [onRemoteStream] is called when the agent's audio track arrives.
  /// [onPeerConnected] is called when the peer connection reaches "connected".
  /// [onPeerConnectionFailed] is called when ICE/connection state becomes failed.
  Future<void> acceptCall({
    required Map<String, dynamic> remoteSdp,
    required String callId,
    required String room,
    required void Function(Map<String, dynamic> candidate) onIceCandidate,
    required void Function(MediaStream stream) onRemoteStream,
    required void Function() onPeerConnected,
    required void Function() onPeerConnectionFailed,
  }) async {
    _connectionResolved = false;

    // 1. Tell the dashboard we are accepting before any async WebRTC work.
    _socketService.emitCallEvent(CovaoneConstants.socketCallAcceptEvent, {
      'room': room,
      'call_id': callId,
      'caller_role': 'customer',
    });

    // 2. Fetch TURN credentials and microphone in parallel.
    final iceServersFuture = _turnIceService.fetchTurnIceServers();
    final mediaFuture = navigator.mediaDevices
        .getUserMedia({'audio': true, 'video': false});

    final results = await Future.wait([iceServersFuture, mediaFuture]);
    final iceServers = results[0] as List<Map<String, dynamic>>;
    _localStream = results[1] as MediaStream;

    final iceConfig = <String, dynamic>{'iceServers': iceServers};

    // 3. Create peer connection with TURN/STUN servers.
    _peerConnection = await createPeerConnection(iceConfig);

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    // Handle remote audio arriving from the agent.
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream(event.streams[0]);
      }
    };

    // Relay local ICE candidates wrapped in the required nested structure.
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        onIceCandidate({'candidate': candidate.toMap()});
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[Covaone WebRTC] ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _notifyConnectionFailed(onPeerConnectionFailed);
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[Covaone WebRTC] connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _notifyPeerConnected(onPeerConnected);
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _notifyConnectionFailed(onPeerConnectionFailed);
      }
    };

    // 4. Set the remote description (agent's offer) and flush buffered candidates.
    final sdpType = remoteSdp['type'] as String? ?? 'offer';
    final sdpStr = remoteSdp['sdp'] as String? ?? '';
    await _peerConnection!
        .setRemoteDescription(RTCSessionDescription(sdpStr, sdpType));
    _remoteDescriptionSet = true;
    await _flushIceCandidateBuffer();

    // 5. Create the answer and set it as our local description.
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // 6. Send the answer SDP to the agent via the signalling server.
    _socketService.emitCallEvent(CovaoneConstants.socketCallAnswerEvent, {
      'room': room,
      'call_id': callId,
      'caller_role': 'customer',
      'sdp': answer.toMap(),
    });
  }

  void _notifyPeerConnected(void Function() onPeerConnected) {
    if (_connectionResolved) return;
    _connectionResolved = true;
    onPeerConnected();
  }

  void _notifyConnectionFailed(void Function() onPeerConnectionFailed) {
    if (_connectionResolved) return;
    _connectionResolved = true;
    onPeerConnectionFailed();
  }

  /// Adds an ICE candidate received from the remote peer.
  ///
  /// Candidates arriving before the peer connection exists or before
  /// [setRemoteDescription] completes are buffered and applied once both
  /// are ready. Handles both camelCase (`sdpMid`, `sdpMLineIndex`) from browser
  /// agents and snake_case (`sdp_mid`, `sdp_m_line_index`) from other relays.
  Future<void> addIceCandidate(Map<String, dynamic> candidateData) async {
    if (_peerConnection == null || !_remoteDescriptionSet) {
      _iceCandidateBuffer.add(candidateData);
      return;
    }
    await _applyIceCandidate(candidateData);
  }

  Future<void> _flushIceCandidateBuffer() async {
    final buffered = List<Map<String, dynamic>>.from(_iceCandidateBuffer);
    _iceCandidateBuffer.clear();
    for (final c in buffered) {
      await _applyIceCandidate(c);
    }
  }

  Future<void> _applyIceCandidate(Map<String, dynamic> candidateData) async {
    if (_peerConnection == null) return;
    try {
      final raw = candidateData['candidate'];
      final Map<String, dynamic> c =
          raw is Map<String, dynamic> ? raw : candidateData;

      final sdpMid = c['sdp_mid'] as String? ?? c['sdpMid'] as String?;
      final sdpMLineIndex = c['sdp_m_line_index'] as int? ??
          (c['sdpMLineIndex'] as num?)?.toInt();

      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          c['candidate'] as String? ?? '',
          sdpMid,
          sdpMLineIndex,
        ),
      );
    } catch (e) {
      debugPrint('[Covaone WebRTC] addIceCandidate error: $e');
    }
  }

  /// Toggles the local microphone mute state.
  ///
  /// Returns the **new** [isMuted] value (`true` = mic is now muted).
  Future<bool> toggleMute() async {
    final tracks = _localStream?.getAudioTracks() ?? [];
    if (tracks.isEmpty) return false;
    final wasEnabled = tracks.first.enabled;
    for (final track in tracks) {
      track.enabled = !wasEnabled;
    }
    return wasEnabled;
  }

  /// Rejects an incoming call before it is answered.
  Future<void> rejectCall({
    required String callId,
    required String room,
  }) async {
    _socketService.emitCallEvent(CovaoneConstants.socketCallRejectEvent, {
      'room': room,
      'call_id': callId,
      'caller_role': 'customer',
      'end_reason': 'rejected',
    });
    await teardown(callId: callId, room: room, endReason: 'rejected');
  }

  /// Ends the call and releases all local media resources.
  ///
  /// Emits `call_end` via the socket unless [callId] is empty (destroy path).
  Future<void> teardown({
    required String callId,
    required String room,
    required String endReason,
  }) async {
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      _localStream!.dispose();
      _localStream = null;
    }

    await _peerConnection?.close();
    _peerConnection = null;

    _iceCandidateBuffer.clear();
    _remoteDescriptionSet = false;
    _connectionResolved = false;

    if (callId.isNotEmpty) {
      _socketService.emitCallEvent(CovaoneConstants.socketCallEndEvent, {
        'room': room,
        'call_id': callId,
        'caller_role': 'customer',
        'end_reason': endReason,
      });
    }
  }
}
