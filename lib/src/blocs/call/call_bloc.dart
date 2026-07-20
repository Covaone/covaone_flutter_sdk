import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/chat_controller.dart';
import '../../core/constants.dart';
import '../../services/audio_service.dart';
import '../../services/socket_service.dart';
import '../../services/webrtc_service.dart';

part 'call_event.dart';
part 'call_state.dart';

/// Manages the full WebRTC call lifecycle using a single [CallState].
///
/// Subscribes to [SocketService] streams for incoming calls, ICE candidates,
/// and remote hang-ups. Delegates peer-connection management to
/// [WebRtcService] and ringtone/notification audio to [AudioService].
///
/// When an [IncomingCallEvent] arrives and the chat panel is closed, this
/// bloc automatically opens it so the user sees the incoming call overlay.
class CallBloc extends Bloc<CallEvent, CallState> {
  final SocketService _socketService;
  final AudioService _audioService;
  final WebRtcService _webRtcService;

  Timer? _callTimer;
  Timer? _connectTimeoutTimer;
  Timer? _ringTimeoutTimer;

  /// SDP offer stashed between [IncomingCallEvent] and [AcceptCallEvent].
  Map<String, dynamic>? _pendingSdp;

  StreamSubscription<Map<String, dynamic>>? _callInviteSub;
  StreamSubscription<Map<String, dynamic>>? _iceSub;
  StreamSubscription<Map<String, dynamic>>? _callEndedSub;

  /// Optional callback registered by the host app via [CovaoneChat.onIncomingCall].
  void Function(String callId, String agentName)? onIncomingCallCallback;

  CallBloc({
    required SocketService socketService,
    required AudioService audioService,
    required WebRtcService webRtcService,
  })  : _socketService = socketService,
        _audioService = audioService,
        _webRtcService = webRtcService,
        super(const CallState()) {
    on<IncomingCallEvent>(_onIncoming);
    on<AcceptCallEvent>(_onAccept);
    on<RejectCallEvent>(_onReject);
    on<HangupCallEvent>(_onHangup);
    on<ToggleMuteEvent>(_onToggleMute);
    on<IceCandidateReceivedEvent>(_onIceCandidate);
    on<CallEndedByRemoteEvent>(_onEndedByRemote);
    on<CallMissedEvent>(_onMissed);
    on<_CallTickEvent>(_onTick);
    on<_PeerConnectedEvent>(_onPeerConnected);
    on<_PeerConnectionFailedEvent>(_onPeerConnectionFailed);
    on<_ConnectTimeoutEvent>(_onConnectTimeout);
    on<_RingTimeoutEvent>(_onRingTimeout);

    _callInviteSub = _socketService.callInvites.listen(_handleInvite);
    _iceSub = _socketService.iceCandidate.listen(_handleIce);
    _callEndedSub = _socketService.callEnded.listen(_handleCallEnded);
  }

  // ── Socket listeners ──────────────────────────────────────────────────────

  void _handleInvite(Map<String, dynamic> payload) {
    add(IncomingCallEvent(
      callId: payload['call_id'] as String? ?? '',
      room: payload['room'] as String? ?? '',
      agentName: payload['agent_name'] as String? ?? 'Support',
      sdp: payload['sdp'] as Map<String, dynamic>? ?? const {},
    ));
  }

  void _handleIce(Map<String, dynamic> payload) {
    add(IceCandidateReceivedEvent(data: payload));
  }

  void _handleCallEnded(Map<String, dynamic> payload) {
    if (state.status != CallStatus.idle) {
      final callId = payload['call_id'] as String? ?? '';
      add(CallEndedByRemoteEvent(callId: callId));
    }
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  Future<void> _onIncoming(
      IncomingCallEvent event, Emitter<CallState> emit) async {
    // Stash SDP for use when the user accepts.
    _pendingSdp = event.sdp;

    // Emit ringing state FIRST so the overlay is ready before the panel opens.
    // Previously this was emitted after awaiting audio, which caused a race:
    // the modal sheet would open (scheduled via addPostFrameCallback) while
    // the state was still idle, so BlocBuilder initialised with no overlay.
    emit(CallState(
      status: CallStatus.ringing,
      callId: event.callId,
      agentName: event.agentName,
      room: event.room,
    ));

    // Open the panel after the state is already ringing — BlocBuilder will
    // read the current state on init and show IncomingCallOverlay immediately.
    if (!CovaoneChatController.panelOpen.value) {
      CovaoneChatController.open();
    }

    onIncomingCallCallback?.call(event.callId, event.agentName);

    // Warm TURN credentials while the user decides whether to accept.
    _webRtcService.prefetchTurnCredentials();
    _startRingTimeout();

    // Fire-and-forget: do not await play() — for looped audio just_audio's
    // play() only resolves when stop() is called, so awaiting it would
    // permanently block this handler and prevent any further state changes.
    unawaited(_audioService.playRingtone());
  }

  Future<void> _onAccept(
      AcceptCallEvent event, Emitter<CallState> emit) async {
    final callId = state.callId;
    final room = state.room;
    if (callId == null || room == null) return;

    await _audioService.stopRingtone();
    _cancelRingTimeout();

    try {
      await _webRtcService.acceptCall(
        remoteSdp: _pendingSdp ?? const {},
        callId: callId,
        room: room,
        onIceCandidate: (candidateMap) {
          _socketService.emitCallEvent('ice_candidate', {
            'room': room,
            'call_id': callId,
            'caller_role': 'customer',
            ...candidateMap,
          });
        },
        onRemoteStream: (_) {
          // Audio-only call — flutter_webrtc handles the remote audio track
          // natively via the platform audio session; no UI rendering needed.
        },
        onPeerConnected: () {
          if (!isClosed) add(const _PeerConnectedEvent());
        },
        onPeerConnectionFailed: () {
          if (!isClosed) add(const _PeerConnectionFailedEvent());
        },
      );

      _pendingSdp = null;

      // SDP exchange is done; stay in "connecting" until WebRTC reaches
      // "connected" or times out. Do NOT end the call on a short timer here.
      emit(state.copyWith(
        status: CallStatus.connecting,
        durationSeconds: 0,
        isMuted: false,
        error: null,
      ));
      _startConnectTimeout();
    } catch (e) {
      await _webRtcService.teardown(
          callId: callId, room: room, endReason: 'error');
      _cleanup();
      emit(const CallState(status: CallStatus.ended));
      await _resetAfterDelay(emit);
    }
  }

  void _onPeerConnected(_PeerConnectedEvent event, Emitter<CallState> emit) {
    if (state.status != CallStatus.connecting) return;
    _cancelConnectTimeout();
    _startTimer();
    emit(state.copyWith(status: CallStatus.active));
  }

  Future<void> _onPeerConnectionFailed(
      _PeerConnectionFailedEvent event, Emitter<CallState> emit) async {
    if (state.status != CallStatus.connecting) return;
    await _endCallWithReason(emit, endReason: 'connection_failed');
  }

  Future<void> _onConnectTimeout(
      _ConnectTimeoutEvent event, Emitter<CallState> emit) async {
    if (state.status != CallStatus.connecting) return;
    await _endCallWithReason(emit, endReason: 'connect_timeout');
  }

  Future<void> _onRingTimeout(
      _RingTimeoutEvent event, Emitter<CallState> emit) async {
    if (state.status != CallStatus.ringing) return;
    await _audioService.stopRingtone();
    final callId = state.callId ?? '';
    final room = state.room ?? '';
    await _webRtcService.rejectCall(callId: callId, room: room);
    _cleanup();
    emit(const CallState(status: CallStatus.ended));
    await _resetAfterDelay(emit);
  }

  Future<void> _onReject(
      RejectCallEvent event, Emitter<CallState> emit) async {
    await _audioService.stopRingtone();
    _cancelRingTimeout();
    final callId = state.callId ?? '';
    final room = state.room ?? '';
    await _webRtcService.rejectCall(callId: callId, room: room);
    _cleanup();
    emit(const CallState(status: CallStatus.ended));
    await _resetAfterDelay(emit);
  }

  Future<void> _onHangup(
      HangupCallEvent event, Emitter<CallState> emit) async {
    final callId = state.callId ?? '';
    final room = state.room ?? '';
    await _webRtcService.teardown(
        callId: callId, room: room, endReason: 'customer_hangup');
    await _audioService.stopRingtone();
    _cleanup();
    emit(const CallState(status: CallStatus.ended));
    await _resetAfterDelay(emit);
  }

  Future<void> _onToggleMute(
      ToggleMuteEvent event, Emitter<CallState> emit) async {
    final isMuted = await _webRtcService.toggleMute();
    emit(state.copyWith(isMuted: isMuted));
  }

  Future<void> _onIceCandidate(
      IceCandidateReceivedEvent event, Emitter<CallState> emit) async {
    await _webRtcService.addIceCandidate(event.data);
  }

  Future<void> _onEndedByRemote(
      CallEndedByRemoteEvent event, Emitter<CallState> emit) async {
    await _audioService.stopRingtone();
    _cancelRingTimeout();
    _cancelConnectTimeout();
    await _webRtcService.teardown(
      callId: event.callId,
      room: state.room ?? '',
      endReason: 'remote_end',
    );
    _cleanup();
    emit(const CallState(status: CallStatus.ended));
    await _resetAfterDelay(emit);
  }

  Future<void> _onMissed(
      CallMissedEvent event, Emitter<CallState> emit) async {
    await _audioService.stopRingtone();
    _cleanup();
    emit(const CallState(status: CallStatus.ended));
    await _resetAfterDelay(emit);
  }

  void _onTick(_CallTickEvent event, Emitter<CallState> emit) {
    if (state.status == CallStatus.active) {
      emit(state.copyWith(durationSeconds: state.durationSeconds + 1));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _startTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) add(const _CallTickEvent());
    });
  }

  void _startConnectTimeout() {
    _cancelConnectTimeout();
    _connectTimeoutTimer = Timer(CovaoneConstants.callConnectTimeout, () {
      if (!isClosed) add(const _ConnectTimeoutEvent());
    });
  }

  void _cancelConnectTimeout() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
  }

  void _startRingTimeout() {
    _cancelRingTimeout();
    _ringTimeoutTimer = Timer(CovaoneConstants.callRingTimeout, () {
      if (!isClosed) add(const _RingTimeoutEvent());
    });
  }

  void _cancelRingTimeout() {
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;
  }

  Future<void> _endCallWithReason(
    Emitter<CallState> emit, {
    required String endReason,
  }) async {
    final callId = state.callId ?? '';
    final room = state.room ?? '';
    _cancelConnectTimeout();
    await _webRtcService.teardown(
      callId: callId,
      room: room,
      endReason: endReason,
    );
    await _audioService.stopRingtone();
    _cleanup();
    emit(const CallState(status: CallStatus.ended));
    await _resetAfterDelay(emit);
  }

  void _cleanup() {
    _callTimer?.cancel();
    _callTimer = null;
    _cancelConnectTimeout();
    _cancelRingTimeout();
    _pendingSdp = null;
  }

  /// Briefly holds the [CallStatus.ended] state then returns to [CallStatus.idle].
  Future<void> _resetAfterDelay(Emitter<CallState> emit) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!isClosed) emit(const CallState());
  }

  @override
  Future<void> close() async {
    _callInviteSub?.cancel();
    _iceSub?.cancel();
    _callEndedSub?.cancel();
    _cleanup();
    return super.close();
  }
}
