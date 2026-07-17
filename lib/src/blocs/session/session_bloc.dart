import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config.dart';
import '../../data/local/session_storage.dart';
import '../../data/models/message_model.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../services/socket_service.dart';

part 'session_event.dart';
part 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final ChatRepository _chatRepository;
  final SessionStorage _sessionStorage;
  final SocketService _socketService;
  final CovaoneConfig _config;

  /// Retained for [NewConversationEvent] / [SetProfileEvent] to re-use.
  String? _publicKey;

  SessionBloc({
    required ChatRepository chatRepository,
    required SessionStorage sessionStorage,
    required SocketService socketService,
    required CovaoneConfig config,
  })  : _chatRepository = chatRepository,
        _sessionStorage = sessionStorage,
        _socketService = socketService,
        _config = config,
        super(const SessionInitial()) {
    on<CovaoneInitializeEvent>(_onInitialize);
    on<CreateSessionEvent>(_onCreate);
    on<GetSessionEvent>(_onGetSession);
    on<SetProfileEvent>(_onSetProfile);
    on<NewConversationEvent>(_onNewConversation);
    on<RefreshSessionIfStaleEvent>(_onRefreshIfStale);
    on<UpdateSessionMessagesEvent>(_onUpdateMessages);
  }

  // ── Public helpers ────────────────────────────────────────────────────────

  /// Returns the active session ID if the bloc is in a session-bearing state.
  String? get currentSessionId {
    final s = state;
    if (s is SessionLoaded) return s.session.sessionId;
    if (s is SessionProfileFormVisible) return s.session.sessionId;
    if (s is SessionSettingProfile) return s.session.sessionId;
    return null;
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _onInitialize(
      CovaoneInitializeEvent event, Emitter<SessionState> emit) async {
    _publicKey = event.publicKey;
    emit(const SessionLoading());
    try {
      final storedId = await _sessionStorage.getSessionId();
      if (storedId == null) {
        add(CreateSessionEvent(publicKey: event.publicKey));
        return;
      }

      final cached = await _sessionStorage.getCachedSession();
      if (cached != null && cached.sessionId == storedId) {
        _emitFromSession(cached, emit);
        return;
      }

      add(GetSessionEvent(sessionId: storedId));
    } catch (e) {
      emit(SessionError(message: _message(e)));
    }
  }

  Future<void> _onCreate(
      CreateSessionEvent event, Emitter<SessionState> emit) async {
    emit(const SessionLoading());
    try {
      final sessionId =
          await _chatRepository.initiateSession(event.publicKey);
      await _sessionStorage.saveSessionId(sessionId);
      add(GetSessionEvent(sessionId: sessionId));
    } catch (e) {
      emit(SessionError(message: _message(e)));
    }
  }

  Future<void> _onGetSession(
      GetSessionEvent event, Emitter<SessionState> emit) async {
    final hadSessionState = state is SessionLoaded ||
        state is SessionProfileFormVisible ||
        state is SessionSettingProfile;

    if (!hadSessionState) {
      emit(const SessionLoading());
    }

    try {
      final session = await _chatRepository.getSession(event.sessionId);
      _emitFromSession(session, emit);
    } catch (e) {
      if (_publicKey != null && !hadSessionState) {
        await _sessionStorage.clearSessionId();
        await _sessionStorage.clearSessionCache();
        add(CreateSessionEvent(publicKey: _publicKey!));
        return;
      }
      emit(SessionError(message: _message(e)));
    }
  }

  Future<void> _onRefreshIfStale(
      RefreshSessionIfStaleEvent event, Emitter<SessionState> emit) async {
    final sessionId = currentSessionId;
    if (sessionId == null) return;

    final lastSync = await _sessionStorage.getSessionSyncAt();
    if (!_config.isSessionSyncExpired(lastSync)) return;

    try {
      final session = await _chatRepository.getSession(sessionId);
      _emitFromSession(session, emit);
    } catch (_) {
      // Keep the cached session when a background refresh fails.
    }
  }

  Future<void> _onSetProfile(
      SetProfileEvent event, Emitter<SessionState> emit) async {
    final sessionId = currentSessionId;
    if (sessionId == null) {
      emit(const SessionError(message: 'No active session'));
      return;
    }

    final current = state;
    final SessionModel session;
    final Color themeColor;
    if (current is SessionProfileFormVisible) {
      session = current.session;
      themeColor = current.themeColor;
    } else if (current is SessionSettingProfile) {
      session = current.session;
      themeColor = current.themeColor;
    } else if (current is SessionLoaded) {
      session = current.session;
      themeColor = current.themeColor;
    } else {
      emit(const SessionError(message: 'No active session'));
      return;
    }

    emit(SessionSettingProfile(session: session, themeColor: themeColor));

    try {
      final updatedSession = await _chatRepository.setProfile(
        sessionId: sessionId,
        email: event.email,
        name: event.name,
      );
      await _sessionStorage.saveEmail(event.email);

      _connectSocket(updatedSession.sessionId);

      emit(SessionLoaded(
        session: updatedSession,
        initials: updatedSession.configuration.initials,
        themeColor: _parseColor(updatedSession.configuration.color),
      ));
    } catch (e) {
      emit(SessionProfileFormVisible(
        session: session,
        themeColor: themeColor,
        profileError: _message(e),
      ));
    }
  }

  Future<void> _onNewConversation(
      NewConversationEvent event, Emitter<SessionState> emit) async {
    final key = _publicKey;
    if (key == null) {
      emit(const SessionError(message: 'SDK not initialised'));
      return;
    }
    emit(const SessionLoading());
    try {
      _socketService.disconnect();
      await _sessionStorage.clearSessionId();
      await _sessionStorage.clearSessionCache();
      await _sessionStorage.clearBroadcastCache();

      final sessionId = await _chatRepository.initiateSession(key);
      await _sessionStorage.saveSessionId(sessionId);
      add(GetSessionEvent(sessionId: sessionId));
    } catch (e) {
      emit(SessionError(message: _message(e)));
    }
  }

  void _onUpdateMessages(
      UpdateSessionMessagesEvent event, Emitter<SessionState> emit) {
    final current = state;
    if (current is! SessionLoaded) return;

    final next = List<MessageModel>.unmodifiable(event.messages);
    if (_sameMessageIds(current.session.messages, next)) return;

    emit(SessionLoaded(
      session: current.session.copyWith(messages: next),
      initials: current.initials,
      themeColor: current.themeColor,
    ));
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  bool _sameMessageIds(List<MessageModel> a, List<MessageModel> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].messageId != b[i].messageId) return false;
    }
    return true;
  }

  void _emitFromSession(SessionModel session, Emitter<SessionState> emit) {
    final themeColor = _parseColor(session.configuration.color);
    final initials = session.configuration.initials;

    if (!session.hasProfile) {
      emit(SessionProfileFormVisible(session: session, themeColor: themeColor));
      return;
    }

    _connectSocket(session.sessionId);
    emit(SessionLoaded(
      session: session,
      initials: initials,
      themeColor: themeColor,
    ));
  }

  void _connectSocket(String sessionId) {
    _socketService.connect(_config.wsBase, sessionId);
  }

  Color _parseColor(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      final value = int.parse(
          cleaned.length == 6 ? 'FF$cleaned' : cleaned,
          radix: 16);
      return Color(value);
    } catch (_) {
      return const Color(0xFF592C83);
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
