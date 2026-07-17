part of 'call_bloc.dart';

/// UI-level call lifecycle phase.
enum CallStatus {
  /// No active call.
  idle,

  /// An incoming call is ringing — show accept/decline controls.
  ringing,

  /// User accepted; SDP exchange complete, waiting for WebRTC ICE to connect.
  connecting,

  /// WebRTC peer connection reached "connected" state — call is live.
  active,

  /// Call has just ended — briefly shown before returning to [idle].
  ended,
}

/// Unified, immutable call state consumed by all call-related UI components.
class CallState extends Equatable {
  /// Current lifecycle phase.
  final CallStatus status;

  /// Backend call identifier. `null` when [status] is [CallStatus.idle].
  final String? callId;

  /// Agent display name. `null` when [status] is [CallStatus.idle].
  final String? agentName;

  /// Socket room / session identifier used for signalling.
  final String? room;

  /// Whether the local microphone is currently muted.
  final bool isMuted;

  /// Elapsed call duration in whole seconds. Incremented every second while
  /// [status] == [CallStatus.active].
  final int durationSeconds;

  /// Last error message, if any. Cleared on each new incoming call.
  final String? error;

  const CallState({
    this.status = CallStatus.idle,
    this.callId,
    this.agentName,
    this.room,
    this.isMuted = false,
    this.durationSeconds = 0,
    this.error,
  });

  /// Returns a new [CallState] with only the supplied fields changed.
  CallState copyWith({
    CallStatus? status,
    Object? callId = _callSentinel,
    Object? agentName = _callSentinel,
    Object? room = _callSentinel,
    bool? isMuted,
    int? durationSeconds,
    Object? error = _callSentinel,
  }) =>
      CallState(
        status: status ?? this.status,
        callId: callId == _callSentinel ? this.callId : callId as String?,
        agentName:
            agentName == _callSentinel ? this.agentName : agentName as String?,
        room: room == _callSentinel ? this.room : room as String?,
        isMuted: isMuted ?? this.isMuted,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        error: error == _callSentinel ? this.error : error as String?,
      );

  @override
  List<Object?> get props =>
      [status, callId, agentName, room, isMuted, durationSeconds, error];
}

const _callSentinel = Object();
