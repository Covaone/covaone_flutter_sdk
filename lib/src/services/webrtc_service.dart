import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/constants.dart';
import 'socket_service.dart';

/// Manages the WebRTC peer connection for voice calls.
///
/// Instantiated once via [CovaoneDI] and injected into [CallBloc].
/// All peer-connection setup, SDP exchange, and media track management are
/// contained here so that [CallBloc] remains focused on UI state only.
class WebRtcService {
  final SocketService _socketService;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  /// Incoming ICE candidates that arrived before [setRemoteDescription]
  /// completed. Flushed immediately after the remote description is set.
  final List<Map<String, dynamic>> _iceCandidateBuffer = [];
  bool _remoteDescriptionSet = false;

  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  WebRtcService({required SocketService socketService})
      : _socketService = socketService;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Accepts an incoming call.
  ///
  /// Steps (per signalling contract):
  /// 1. Emit `call_accept` immediately (tells dashboard we are connecting).
  /// 2. Create RTCPeerConnection with STUN servers.
  /// 3. Request microphone (audio-only) and add tracks.
  /// 4. Set the agent's remote SDP offer; flush any buffered ICE candidates.
  /// 5. Create SDP answer, set as local description.
  /// 6. Emit `call_answer` with the answer SDP.
  ///
  /// [onIceCandidate] is called for each local ICE candidate to be forwarded.
  /// [onRemoteStream] is called when the agent's audio track arrives.
  /// [onPeerConnected] is called when RTCPeerConnectionState reaches
  ///   "connected" — this is the correct moment to start the call timer.
  Future<void> acceptCall({
    required Map<String, dynamic> remoteSdp,
    required String callId,
    required String room,
    required void Function(Map<String, dynamic> candidate) onIceCandidate,
    required void Function(MediaStream stream) onRemoteStream,
    required void Function() onPeerConnected,
  }) async {
    // 1. Tell the dashboard we are accepting before any async WebRTC work.
    _socketService.emitCallEvent(CovaoneConstants.socketCallAcceptEvent, {
      'room': room,
      'call_id': callId,
      'caller_role': 'customer',
    });

    // 2. Create peer connection.
    _peerConnection = await createPeerConnection(_iceConfig);

    // 3. Obtain microphone stream and add audio tracks.
    _localStream = await navigator.mediaDevices
        .getUserMedia({'audio': true, 'video': false});
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
    // toMap() returns {candidate, sdpMid, sdpMLineIndex} — nest it under
    // the "candidate" key as required by the signalling contract.
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        onIceCandidate({'candidate': candidate.toMap()});
      }
    };

    // Fire onPeerConnected when ICE negotiation fully completes.
    // This is the ONLY correct moment to start the call timer on mobile.
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[Covaone WebRTC] connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onPeerConnected();
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

  /// Adds an ICE candidate received from the remote peer.
  ///
  /// Candidates arriving before [setRemoteDescription] completes are buffered
  /// and applied automatically once it is safe to do so. Handles both
  /// camelCase (`sdpMid`, `sdpMLineIndex`) from browser agents and snake_case
  /// (`sdp_mid`, `sdp_m_line_index`) from other relay formats.
  Future<void> addIceCandidate(Map<String, dynamic> candidateData) async {
    if (!_remoteDescriptionSet || _peerConnection == null) {
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
    try {
      // The full socket payload wraps the actual ICE fields inside a nested
      // "candidate" object. Unwrap it; fall back to the flat map for resilience.
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
      // Non-fatal — ICE negotiation continues with remaining candidates.
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
    return wasEnabled; // was enabled → now disabled → isMuted = true
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
    // Stop and dispose local media stream.
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      _localStream!.dispose();
      _localStream = null;
    }

    // Close and null the peer connection.
    await _peerConnection?.close();
    _peerConnection = null;

    // Reset ICE buffer state for the next call.
    _iceCandidateBuffer.clear();
    _remoteDescriptionSet = false;

    // Only emit call_end for real call sessions, not on SDK destroy.
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
