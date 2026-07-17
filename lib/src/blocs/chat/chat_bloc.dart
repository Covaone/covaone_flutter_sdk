import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/chat_controller.dart';
import '../../data/local/session_storage.dart';
import '../../data/models/message_model.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../services/audio_service.dart';
import '../../services/socket_service.dart';
import '../session/session_bloc.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _chatRepository;
  final SessionStorage _sessionStorage;
  final SocketService _socketService;
  final AudioService _audioService;
  final SessionBloc _sessionBloc;

  StreamSubscription<MessageModel>? _messageSub;
  StreamSubscription<SessionState>? _sessionSub;

  /// Alert message IDs the user dismissed one-by-one from the sticky stack.
  /// Kept so sync/hydrate do not revive a card the user already swiped away.
  final Set<String> _dismissedAlertIds = {};

  ChatBloc({
    required ChatRepository chatRepository,
    required SessionStorage sessionStorage,
    required SocketService socketService,
    required AudioService audioService,
    required SessionBloc sessionBloc,
  })  : _chatRepository = chatRepository,
        _sessionStorage = sessionStorage,
        _socketService = socketService,
        _audioService = audioService,
        _sessionBloc = sessionBloc,
        super(const ChatState()) {
    // ── Navigation ────────────────────────────────────────────────────────────
    on<ChatTabChangedEvent>(_onTabChanged);
    on<OpenChatEvent>(_onOpenChat);
    on<CloseChatEvent>(_onCloseChat);

    // ── Session / socket ──────────────────────────────────────────────────────
    on<MessagesLoadedEvent>(_onMessagesLoaded);
    on<FetchMessagesEvent>(_onFetchMessages);
    on<SocketConnectEvent>(_onSocketConnect);

    // ── Messaging ─────────────────────────────────────────────────────────────
    on<SendTextMessageEvent>(_onSendText);
    on<SendFileMessageEvent>(_onSendFile);
    on<MessageReceivedEvent>(_onMessageReceived);
    on<TypingStartedEvent>(_onTypingStarted);
    on<_TypingTimeoutEvent>(_onTypingTimeout);

    // ── File attachment ───────────────────────────────────────────────────────
    on<FileSelectedEvent>(_onFileSelected);
    on<FileClearedEvent>(_onFileCleared);

    // ── Housekeeping ──────────────────────────────────────────────────────────
    on<MarkMessagesReadEvent>(_onMarkRead);
    on<DismissMessageAlertEvent>(_onDismissMessageAlert);
    on<SyncUnreadAlertsFromMessagesEvent>(_onSyncUnreadAlerts);
    on<ClearMessagesEvent>(_onClear);
    on<_HydrateChatMetaEvent>(_onHydrateChatMeta);

    // Subscribe to the socket stream.
    _messageSub = _socketService.incomingMessages.listen(_handleSocketMessage);

    // Restore persisted alerts first; session watching starts after hydrate.
    unawaited(_hydrateChatMeta());
  }

  Future<void> _hydrateChatMeta() async {
    final results = await Future.wait([
      _sessionStorage.getLastChatOpenedAt(),
      _sessionStorage.getLastMessageAlertClearedAt(),
      _sessionStorage.getCachedSession(),
      _sessionStorage.getPendingMessageAlerts(),
      _sessionStorage.getDismissedMessageAlertIds(),
    ]);
    if (isClosed) return;

    add(_HydrateChatMetaEvent(
      lastChatOpenedAt: results[0] as DateTime?,
      lastMessageAlertClearedAt: results[1] as DateTime?,
      cachedSession: results[2] as SessionModel?,
      persistedAlerts: results[3] as List<MessageModel>,
      dismissedAlertIds: results[4] as Set<String>,
    ));
  }

  void _onHydrateChatMeta(
      _HydrateChatMetaEvent event, Emitter<ChatState> emit) {
    _dismissedAlertIds
      ..clear()
      ..addAll(event.dismissedAlertIds);

    final chatVisible =
        state.isChatOpen && CovaoneChatController.panelOpen.value;
    final openedAt = event.lastChatOpenedAt ?? state.lastChatOpenedAt;
    final clearedAt =
        event.lastMessageAlertClearedAt ?? state.lastMessageAlertClearedAt;

    // Persisted socket alerts are authoritative until open/dismiss.
    final fromDisk = chatVisible
        ? const <MessageModel>[]
        : _filterPersistedAlerts(
            event.persistedAlerts,
            openedAt: openedAt,
            clearedAt: clearedAt,
          );
    final fromMessages = chatVisible
        ? const <MessageModel>[]
        : _unreadAlertsFromMessages(
            event.cachedSession?.messages ?? state.messages,
            openedAt: openedAt,
            clearedAt: clearedAt,
          );
    final alerts = _withoutDismissed(_mergeAlerts(fromDisk, fromMessages));

    emit(state.copyWith(
      lastChatOpenedAt: openedAt,
      lastMessageAlertClearedAt: clearedAt,
      sessionId: event.cachedSession?.sessionId.isNotEmpty == true
          ? event.cachedSession!.sessionId
          : state.sessionId,
      messages: event.cachedSession != null
          ? List.unmodifiable(
              _mergeMessages(state.messages, event.cachedSession!.messages))
          : state.messages,
      pendingMessageAlerts: alerts,
      unreadCount: alerts.isEmpty ? state.unreadCount : alerts.length,
    ));

    // Start watching session only after alerts are restored.
    _sessionSub ??= _sessionBloc.stream.listen(_onSessionStateChanged);
    _onSessionStateChanged(_sessionBloc.state);
  }

  void _onSessionStateChanged(SessionState sessionState) {
    final session = _sessionFromState(sessionState);
    if (session == null || isClosed) return;
    add(SyncUnreadAlertsFromMessagesEvent(
      messages: session.messages,
      sessionId: session.sessionId,
    ));
  }

  SessionModel? _sessionFromState(SessionState sessionState) {
    if (sessionState is SessionLoaded) return sessionState.session;
    if (sessionState is SessionProfileFormVisible) return sessionState.session;
    if (sessionState is SessionSettingProfile) return sessionState.session;
    return null;
  }

  // ── Public helpers ────────────────────────────────────────────────────────

  int get unreadCount => state.unreadCount;

  // ── Socket stream handler ─────────────────────────────────────────────────

  void _handleSocketMessage(MessageModel msg) {
    if (isClosed) return;
    // Skip customer-originated echoes — we already show them optimistically.
    if (msg.isFromCustomer) return;

    if (msg.isCallLog) {
      // Call logs are appended immediately with no typing delay.
      add(MessageReceivedEvent(message: msg));
      return;
    }

    // Agent REPLY: show typing bubble for 2 s then reveal the message.
    add(const TypingStartedEvent());
    Future.delayed(const Duration(seconds: 2), () {
      if (!isClosed) add(_TypingTimeoutEvent(msg));
    });
  }

  // ── Navigation handlers ───────────────────────────────────────────────────

  void _onTabChanged(ChatTabChangedEvent event, Emitter<ChatState> emit) {
    emit(state.copyWith(currentTab: event.tab, isChatOpen: false));
  }

  void _onOpenChat(OpenChatEvent event, Emitter<ChatState> emit) {
    final openedAt = DateTime.now();
    _clearDismissedAlertIds();
    unawaited(_sessionStorage.saveLastChatOpenedAt(openedAt));
    unawaited(_sessionStorage.saveLastMessageAlertClearedAt(openedAt));
    unawaited(_sessionStorage.savePendingMessageAlerts(const []));
    emit(state.copyWith(
      isChatOpen: true,
      isNewChat: event.isNew,
      isLoading: true,
      lastChatOpenedAt: openedAt,
      lastMessageAlertClearedAt: openedAt,
      pendingMessageAlerts: const [],
      unreadCount: 0,
    ));
  }

  void _onCloseChat(CloseChatEvent event, Emitter<ChatState> emit) {
    emit(state.copyWith(isChatOpen: false, isNewChat: false));
  }

  // ── Session / socket handlers ─────────────────────────────────────────────

  void _onMessagesLoaded(MessagesLoadedEvent event, Emitter<ChatState> emit) {
    final chatVisible =
        state.isChatOpen && CovaoneChatController.panelOpen.value;
    final derived = chatVisible
        ? const <MessageModel>[]
        : _unreadAlertsFromMessages(
            event.messages,
            openedAt: state.lastChatOpenedAt,
            clearedAt: state.lastMessageAlertClearedAt,
          );
    final alerts = chatVisible
        ? const <MessageModel>[]
        : _withoutDismissed(
            _mergeAlerts(state.pendingMessageAlerts, derived),
          );
    final messages = List<MessageModel>.unmodifiable(event.messages);
    emit(state.copyWith(
      messages: messages,
      sessionId: event.sessionId,
      isLoading: false,
      error: null,
      pendingMessageAlerts: alerts,
      unreadCount: chatVisible ? 0 : alerts.length,
    ));
    _syncSessionMessages(messages);
  }

  Future<void> _onFetchMessages(
      FetchMessagesEvent event, Emitter<ChatState> emit) async {
    emit(state.copyWith(isLoading: true, sessionId: event.sessionId));
    try {
      // Always hit the network when the user opens chat — TTL cache is only
      // for cold-start session bootstrap, not for reading the conversation.
      final session = await _chatRepository.getSession(event.sessionId);

      final chatVisible =
          state.isChatOpen && CovaoneChatController.panelOpen.value;
      final derived = chatVisible
          ? const <MessageModel>[]
          : _unreadAlertsFromMessages(
              session.messages,
              openedAt: state.lastChatOpenedAt,
              clearedAt: state.lastMessageAlertClearedAt,
            );
      final alerts = chatVisible
          ? const <MessageModel>[]
          : _withoutDismissed(
              _mergeAlerts(state.pendingMessageAlerts, derived),
            );

      final messages = List<MessageModel>.unmodifiable(session.messages);
      emit(state.copyWith(
        messages: messages,
        sessionId: session.sessionId,
        isLoading: false,
        error: null,
        pendingMessageAlerts: alerts,
        unreadCount: chatVisible ? 0 : alerts.length,
      ));
      _syncSessionMessages(messages);
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onSocketConnect(SocketConnectEvent event, Emitter<ChatState> emit) {
    // Delegate the actual connection to SocketService (no-op if already connected).
    _socketService.reconnect(event.sessionId);
  }

  // ── Message handlers ──────────────────────────────────────────────────────

  void _onSendText(SendTextMessageEvent event, Emitter<ChatState> emit) {
    if (state.sessionId.isEmpty) return;

    final optimistic = MessageModel.optimistic(
      text: event.text,
      sessionId: state.sessionId,
    );
    final messages = [...state.messages, optimistic];
    emit(state.copyWith(
      messages: messages,
      isSending: true,
    ));
    _syncSessionMessages(messages);

    _socketService.sendMessage(state.sessionId, event.text);
    emit(state.copyWith(isSending: false));
  }

  Future<void> _onSendFile(
      SendFileMessageEvent event, Emitter<ChatState> emit) async {
    if (state.sessionId.isEmpty) return;

    emit(state.copyWith(isSending: true));

    // Optimistic file message (shows local preview while uploading).
    final optimistic = MessageModel(
      messageId: 'upload_${DateTime.now().millisecondsSinceEpoch}',
      message: event.filename,
      messageType: MessageType.QUERY,
      authorType: 'HUMAN',
      origin: 'frontend',
      hasAttachment: true,
      fileUrl: null, // Will be replaced on success
      timeCreated: DateTime.now(),
    );

    final messages = [...state.messages, optimistic];
    emit(state.copyWith(
      messages: messages,
      isFileSelected: false,
      selectedFileName: null,
      selectedFileSize: null,
      pendingFileBase64: null,
      pendingFileMime: null,
    ));
    _syncSessionMessages(messages);

    try {
      await _chatRepository.uploadFileFromBase64(
        conversationId: state.sessionId,
        filename: event.filename,
        base64Content: event.base64Content,
        messageType: 'QUERY',
        origin: 'frontend',
      );
    } catch (e) {
      // Non-fatal — the optimistic message stays in the list.
    } finally {
      emit(state.copyWith(isSending: false));
    }
  }

  void _onTypingStarted(TypingStartedEvent event, Emitter<ChatState> emit) {
    emit(state.copyWith(isTyping: true));
  }

  void _onTypingTimeout(_TypingTimeoutEvent event, Emitter<ChatState> emit) {
    final alreadyPresent =
        state.messages.any((m) => m.messageId == event.message.messageId);
    final updated =
        alreadyPresent ? state.messages : [...state.messages, event.message];

    final panelOpen = CovaoneChatController.panelOpen.value;
    final chatVisible = state.isChatOpen && panelOpen;
    final nextAlerts = chatVisible
        ? const <MessageModel>[]
        : _appendAlert(state.pendingMessageAlerts, event.message);

    // Notification sound only when the panel/chat is not visible.
    if (!chatVisible) {
      _audioService.playMessageNotification();
    }

    emit(state.copyWith(
      messages: updated,
      isTyping: false,
      isSending: false,
      unreadCount: chatVisible ? state.unreadCount : state.unreadCount + 1,
      pendingMessageAlerts: nextAlerts,
    ));
    if (!alreadyPresent) {
      _syncSessionMessages(updated);
    }
    unawaited(_persistIncomingMessage(
      event.message,
      alerts: nextAlerts,
      clearAlerts: chatVisible,
    ));
  }

  void _onMessageReceived(MessageReceivedEvent event, Emitter<ChatState> emit) {
    final alreadyPresent =
        state.messages.any((m) => m.messageId == event.message.messageId);
    if (alreadyPresent) return;

    final panelOpen = CovaoneChatController.panelOpen.value;
    final chatVisible = state.isChatOpen && panelOpen;
    final showAlert = !chatVisible && !event.message.isCallLog;
    final nextAlerts = showAlert
        ? _appendAlert(state.pendingMessageAlerts, event.message)
        : state.pendingMessageAlerts;

    final messages = [...state.messages, event.message];
    emit(state.copyWith(
      messages: messages,
      isTyping: false,
      unreadCount: chatVisible ? state.unreadCount : state.unreadCount + 1,
      pendingMessageAlerts: nextAlerts,
    ));
    _syncSessionMessages(messages);
    unawaited(_persistIncomingMessage(
      event.message,
      alerts: nextAlerts,
      clearAlerts: chatVisible,
    ));
  }

  /// Keeps [SessionBloc] (Conversations tab) aligned with live ChatBloc messages.
  /// Not called from session→chat sync to avoid feedback loops.
  void _syncSessionMessages(List<MessageModel> messages) {
    if (_sessionBloc.isClosed) return;
    _sessionBloc.add(UpdateSessionMessagesEvent(messages: messages));
  }

  Future<void> _persistIncomingMessage(
    MessageModel message, {
    required List<MessageModel> alerts,
    required bool clearAlerts,
  }) async {
    await _sessionStorage.appendMessageToCachedSession(message);
    if (clearAlerts) {
      await _sessionStorage.savePendingMessageAlerts(const []);
    } else {
      await _sessionStorage.savePendingMessageAlerts(alerts);
    }
  }

  List<MessageModel> _appendAlert(
      List<MessageModel> current, MessageModel message) {
    if (_dismissedAlertIds.contains(message.messageId)) return current;
    if (current.any((m) => m.messageId == message.messageId)) return current;
    // Keep a bounded stack so the overlay stays light.
    final next = [...current, message];
    if (next.length <= 12) return next;
    return next.sublist(next.length - 12);
  }

  List<MessageModel> _withoutDismissed(List<MessageModel> alerts) {
    if (_dismissedAlertIds.isEmpty) return alerts;
    return alerts
        .where((m) => !_dismissedAlertIds.contains(m.messageId))
        .toList(growable: false);
  }

  void _clearDismissedAlertIds() {
    if (_dismissedAlertIds.isEmpty) return;
    _dismissedAlertIds.clear();
    unawaited(_sessionStorage.saveDismissedMessageAlertIds(const {}));
  }

  void _onSyncUnreadAlerts(
      SyncUnreadAlertsFromMessagesEvent event, Emitter<ChatState> emit) {
    final chatVisible =
        state.isChatOpen && CovaoneChatController.panelOpen.value;

    // Keep any newer in-memory / socket messages that the session payload
    // has not caught up with yet.
    final mergedMessages = _mergeMessages(state.messages, event.messages);

    if (chatVisible) {
      emit(state.copyWith(
        sessionId: event.sessionId,
        messages: List.unmodifiable(mergedMessages),
        pendingMessageAlerts: const [],
        unreadCount: 0,
      ));
      unawaited(_sessionStorage.savePendingMessageAlerts(const []));
      return;
    }

    final derived = _unreadAlertsFromMessages(
      mergedMessages,
      openedAt: state.lastChatOpenedAt,
      clearedAt: state.lastMessageAlertClearedAt,
    );
    // Never wipe alerts that were restored from disk / socket just because the
    // session cache is still stale after a refresh.
    final alerts = _withoutDismissed(
      _mergeAlerts(state.pendingMessageAlerts, derived),
    );

    emit(state.copyWith(
      sessionId: event.sessionId,
      messages: List.unmodifiable(mergedMessages),
      pendingMessageAlerts: alerts,
      unreadCount: alerts.isEmpty ? state.unreadCount : alerts.length,
    ));
    // Only persist when we still have alerts — never clobber disk with [].
    if (alerts.isNotEmpty) {
      unawaited(_sessionStorage.savePendingMessageAlerts(alerts));
    }
  }

  /// Agent messages newer than the last time the user opened chat or dismissed
  /// the alert stack — these should reappear after an app refresh.
  List<MessageModel> _unreadAlertsFromMessages(
    List<MessageModel> messages, {
    DateTime? openedAt,
    DateTime? clearedAt,
  }) {
    return _filterAlertsByCutoff(
      messages.where((m) => !m.isFromCustomer && !m.isCallLog),
      openedAt: openedAt,
      clearedAt: clearedAt,
      fallbackRecentOnly: true,
    );
  }

  /// Persisted socket alerts survive refresh. Only drop them if the user has
  /// explicitly opened chat or dismissed after that message.
  List<MessageModel> _filterPersistedAlerts(
    Iterable<MessageModel> messages, {
    DateTime? openedAt,
    DateTime? clearedAt,
  }) {
    return _filterAlertsByCutoff(
      messages.where((m) => !m.isFromCustomer && !m.isCallLog),
      openedAt: openedAt,
      clearedAt: clearedAt,
      fallbackRecentOnly: false,
    );
  }

  List<MessageModel> _filterAlertsByCutoff(
    Iterable<MessageModel> messages, {
    DateTime? openedAt,
    DateTime? clearedAt,
    required bool fallbackRecentOnly,
  }) {
    final explicitCutoff = _laterOf(openedAt, clearedAt);
    final cutoff = explicitCutoff ??
        (fallbackRecentOnly
            ? DateTime.now().subtract(const Duration(hours: 24))
            : null);

    final unread = messages.where((m) {
      if (m.isFromCustomer || m.isCallLog) return false;
      if (cutoff == null) return true;
      return m.timeCreated.isAfter(cutoff);
    }).toList()
      ..sort((a, b) => a.timeCreated.compareTo(b.timeCreated));

    if (unread.length <= 12) return unread;
    return unread.sublist(unread.length - 12);
  }

  List<MessageModel> _mergeAlerts(
      List<MessageModel> a, List<MessageModel> b) {
    final byId = <String, MessageModel>{};
    for (final m in [...a, ...b]) {
      byId[m.messageId] = m;
    }
    final merged = byId.values.toList()
      ..sort((x, y) => x.timeCreated.compareTo(y.timeCreated));
    if (merged.length <= 12) return merged;
    return merged.sublist(merged.length - 12);
  }

  List<MessageModel> _mergeMessages(
      List<MessageModel> current, List<MessageModel> incoming) {
    final byId = <String, MessageModel>{};
    for (final m in [...incoming, ...current]) {
      byId[m.messageId] = m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.timeCreated.compareTo(b.timeCreated));
    return merged;
  }

  DateTime? _laterOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  Future<void> _persistAlertClearedAt(DateTime clearedAt) async {
    await _sessionStorage.saveLastMessageAlertClearedAt(clearedAt);
  }

  // ── File attachment handlers ──────────────────────────────────────────────

  void _onFileSelected(FileSelectedEvent event, Emitter<ChatState> emit) {
    emit(state.copyWith(
      isFileSelected: true,
      selectedFileName: event.filename,
      selectedFileSize: event.sizeBytes,
      pendingFileBase64: event.base64Content,
      pendingFileMime: event.mimeType,
    ));
  }

  void _onFileCleared(FileClearedEvent event, Emitter<ChatState> emit) {
    emit(state.copyWith(
      isFileSelected: false,
      selectedFileName: null,
      selectedFileSize: null,
      pendingFileBase64: null,
      pendingFileMime: null,
    ));
  }

  // ── Housekeeping ──────────────────────────────────────────────────────────

  void _onMarkRead(MarkMessagesReadEvent event, Emitter<ChatState> emit) {
    final clearedAt = DateTime.now();
    _clearDismissedAlertIds();
    unawaited(_persistAlertClearedAt(clearedAt));
    unawaited(_sessionStorage.savePendingMessageAlerts(const []));
    emit(state.copyWith(
      unreadCount: 0,
      pendingMessageAlerts: const [],
      lastMessageAlertClearedAt: clearedAt,
    ));
  }

  void _onDismissMessageAlert(
      DismissMessageAlertEvent event, Emitter<ChatState> emit) {
    final alerts = state.pendingMessageAlerts;
    if (alerts.isEmpty) return;

    // Peel only the front (newest) card so the stack beneath stays.
    final dismissed = alerts.last;
    final remaining = alerts.sublist(0, alerts.length - 1);

    if (remaining.isEmpty) {
      final clearedAt = dismissed.timeCreated;
      _clearDismissedAlertIds();
      unawaited(_persistAlertClearedAt(clearedAt));
      unawaited(_sessionStorage.savePendingMessageAlerts(const []));
      emit(state.copyWith(
        pendingMessageAlerts: const [],
        lastMessageAlertClearedAt: clearedAt,
        unreadCount: 0,
      ));
      return;
    }

    _dismissedAlertIds.add(dismissed.messageId);
    unawaited(
        _sessionStorage.saveDismissedMessageAlertIds(_dismissedAlertIds));
    unawaited(_sessionStorage.savePendingMessageAlerts(remaining));
    emit(state.copyWith(
      pendingMessageAlerts: remaining,
      unreadCount: remaining.length,
    ));
  }

  void _onClear(ClearMessagesEvent event, Emitter<ChatState> emit) {
    _clearDismissedAlertIds();
    unawaited(_sessionStorage.savePendingMessageAlerts(const []));
    emit(state.copyWith(
      messages: const [],
      unreadCount: 0,
      pendingMessageAlerts: const [],
    ));
  }

  @override
  Future<void> close() {
    _messageSub?.cancel();
    _sessionSub?.cancel();
    return super.close();
  }
}
