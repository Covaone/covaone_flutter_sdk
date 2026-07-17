part of 'call_bloc.dart';

/// Base class for all call-related events.
abstract class CallEvent extends Equatable {
  const CallEvent();
  @override
  List<Object?> get props => [];
}

/// Dispatched automatically when [SocketService] receives a `call_invite`.
class IncomingCallEvent extends CallEvent {
  /// Backend call identifier.
  final String callId;

  /// Socket room used for signalling.
  final String room;

  /// Agent's display name shown in the UI.
  final String agentName;

  /// Agent's SDP offer payload; must contain at least `type` and `sdp` keys.
  final Map<String, dynamic> sdp;

  const IncomingCallEvent({
    required this.callId,
    required this.room,
    required this.agentName,
    required this.sdp,
  });

  @override
  List<Object?> get props => [callId, room, agentName, sdp];
}

/// User taps "Accept" on the incoming call overlay.
class AcceptCallEvent extends CallEvent {
  const AcceptCallEvent();
}

/// User taps "Decline" on the incoming call overlay.
class RejectCallEvent extends CallEvent {
  const RejectCallEvent();
}

/// User taps "End call" on the active call overlay.
class HangupCallEvent extends CallEvent {
  const HangupCallEvent();
}

/// User taps the mute/unmute button on the active call overlay.
class ToggleMuteEvent extends CallEvent {
  const ToggleMuteEvent();
}

/// ICE candidate received from the agent via the signalling socket.
class IceCandidateReceivedEvent extends CallEvent {
  /// Raw ICE candidate payload from the socket event.
  final Map<String, dynamic> data;
  const IceCandidateReceivedEvent({required this.data});
  @override
  List<Object?> get props => [data];
}

/// Remote party (agent) ended or missed the call.
class CallEndedByRemoteEvent extends CallEvent {
  final String callId;
  const CallEndedByRemoteEvent({required this.callId});
  @override
  List<Object?> get props => [callId];
}

/// Server notified that the call was missed (agent disconnected before answer).
class CallMissedEvent extends CallEvent {
  final String callId;
  const CallMissedEvent({required this.callId});
  @override
  List<Object?> get props => [callId];
}

// ── Internal events ───────────────────────────────────────────────────────────

/// Fired every second by the duration timer while the call is active.
class _CallTickEvent extends CallEvent {
  const _CallTickEvent();
}

/// Fired when the WebRTC RTCPeerConnection transitions to the "connected"
/// state. Only at this point should the call timer start and the active
/// UI be shown.
class _PeerConnectedEvent extends CallEvent {
  const _PeerConnectedEvent();
}
