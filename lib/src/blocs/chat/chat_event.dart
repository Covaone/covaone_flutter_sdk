part of 'chat_bloc.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

// ── Navigation ─────────────────────────────────────────────────────────────────

class ChatTabChangedEvent extends ChatEvent {
  final ChatTab tab;
  const ChatTabChangedEvent({required this.tab});
  @override
  List<Object?> get props => [tab];
}

class OpenChatEvent extends ChatEvent {
  /// True when launched from the "Send us a Message" CTA.
  final bool isNew;

  /// Optional text to prefill in the message composer (e.g. support prompt).
  final String? draftMessage;

  /// Optional technical error payload attached on the next outbound send.
  final MessageErrorInfo? errorInfo;

  const OpenChatEvent({
    this.isNew = false,
    this.draftMessage,
    this.errorInfo,
  });
  @override
  List<Object?> get props => [isNew, draftMessage, errorInfo];
}

class CloseChatEvent extends ChatEvent {
  const CloseChatEvent();
}

/// Clears [ChatState.draftMessage] after the composer has applied it.
class ClearDraftMessageEvent extends ChatEvent {
  const ClearDraftMessageEvent();
}

// ── Session / socket ───────────────────────────────────────────────────────────

/// Seed the messages list from the session data on first open.
class MessagesLoadedEvent extends ChatEvent {
  final List<MessageModel> messages;
  final String sessionId;
  const MessagesLoadedEvent({required this.messages, required this.sessionId});
  @override
  List<Object?> get props => [messages, sessionId];
}

/// Re-fetches the session from the server to get the latest messages.
/// Shows a loading indicator while in flight.
class FetchMessagesEvent extends ChatEvent {
  final String sessionId;
  const FetchMessagesEvent({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}

/// Connects the socket (called after lead-capture form succeeds).
class SocketConnectEvent extends ChatEvent {
  final String sessionId;
  const SocketConnectEvent({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}

// ── Messaging ─────────────────────────────────────────────────────────────────

/// Send a plain text message via the WebSocket.
class SendTextMessageEvent extends ChatEvent {
  final String text;
  const SendTextMessageEvent({required this.text});
  @override
  List<Object?> get props => [text];
}

/// Upload a file attachment via REST then emit a message.
class SendFileMessageEvent extends ChatEvent {
  final String filename;
  final String base64Content;
  final String mimeType;
  final int sizeBytes;

  const SendFileMessageEvent({
    required this.filename,
    required this.base64Content,
    required this.mimeType,
    required this.sizeBytes,
  });

  @override
  List<Object?> get props => [filename, base64Content, mimeType, sizeBytes];
}

/// Dispatched by the socket listener when a new inbound message is ready
/// (after any typing-indicator delay has elapsed).
class MessageReceivedEvent extends ChatEvent {
  final MessageModel message;
  const MessageReceivedEvent({required this.message});
  @override
  List<Object?> get props => [message];
}

/// Shows the typing-bubble for 2 seconds before the real message appears.
class TypingStartedEvent extends ChatEvent {
  const TypingStartedEvent();
}

// ── File attachment ────────────────────────────────────────────────────────────

/// User selected a file; preview it before sending.
class FileSelectedEvent extends ChatEvent {
  final String filename;
  final String base64Content;
  final String mimeType;
  final int sizeBytes;

  const FileSelectedEvent({
    required this.filename,
    required this.base64Content,
    required this.mimeType,
    required this.sizeBytes,
  });

  @override
  List<Object?> get props => [filename, base64Content, mimeType, sizeBytes];
}

/// Clear the pending file selection.
class FileClearedEvent extends ChatEvent {
  const FileClearedEvent();
}

// ── Housekeeping ───────────────────────────────────────────────────────────────

class MarkMessagesReadEvent extends ChatEvent {
  const MarkMessagesReadEvent();
}

/// Dismisses the top sticky in-app message alert (swipe or close).
/// With a stacked deck, only the front card is removed so older alerts remain.
class DismissMessageAlertEvent extends ChatEvent {
  const DismissMessageAlertEvent();
}

/// Rebuilds sticky alerts from session messages that arrived after the user
/// last opened chat (or last dismissed the alert stack).
class SyncUnreadAlertsFromMessagesEvent extends ChatEvent {
  final List<MessageModel> messages;
  final String sessionId;

  const SyncUnreadAlertsFromMessagesEvent({
    required this.messages,
    required this.sessionId,
  });

  @override
  List<Object?> get props => [messages, sessionId];
}

class ClearMessagesEvent extends ChatEvent {
  const ClearMessagesEvent();
}

// ── Internal (not dispatched by UI) ───────────────────────────────────────────

/// Carries the real message after the 2-second typing delay fires.
class _TypingTimeoutEvent extends ChatEvent {
  final MessageModel message;
  const _TypingTimeoutEvent(this.message);
  @override
  List<Object?> get props => [message];
}

/// Seeds persisted chat meta and restores unread sticky alerts after restart.
class _HydrateChatMetaEvent extends ChatEvent {
  final DateTime? lastChatOpenedAt;
  final DateTime? lastMessageAlertClearedAt;
  final SessionModel? cachedSession;
  final List<MessageModel> persistedAlerts;
  final Set<String> dismissedAlertIds;

  const _HydrateChatMetaEvent({
    this.lastChatOpenedAt,
    this.lastMessageAlertClearedAt,
    this.cachedSession,
    this.persistedAlerts = const [],
    this.dismissedAlertIds = const {},
  });

  @override
  List<Object?> get props => [
        lastChatOpenedAt,
        lastMessageAlertClearedAt,
        cachedSession,
        persistedAlerts,
        dismissedAlertIds,
      ];
}
