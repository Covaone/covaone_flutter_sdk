part of 'chat_bloc.dart';

/// The three main panel tabs.
enum ChatTab { home, conversations, faq }

/// Single unified state for [ChatBloc].
///
/// All navigation, message, typing, and file fields live here so that every
/// consumer can read any property without a runtime `is` check.
class ChatState extends Equatable {
  // ── Navigation ─────────────────────────────────────────────────────────────
  final ChatTab currentTab;
  final bool isChatOpen;

  /// True when chat was opened from the home CTA (fresh conversation).
  final bool isNewChat;

  // ── Session ─────────────────────────────────────────────────────────────────
  final String sessionId;

  // ── Messages ─────────────────────────────────────────────────────────────────
  final List<MessageModel> messages;

  /// True while the 2-second typing bubble is displayed.
  final bool isTyping;

  /// True while an optimistic message is being sent to the socket.
  final bool isSending;

  /// True while the initial session/messages are being fetched.
  final bool isLoading;

  final int unreadCount;
  final String? error;

  /// Agent messages waiting as sticky bottom alerts while chat is not visible.
  /// Newest last; the UI shows the latest on top with stacked cards behind.
  final List<MessageModel> pendingMessageAlerts;

  /// Last time the chat / "Send us a Message" screen was opened.
  final DateTime? lastChatOpenedAt;

  /// Last time the sticky alert stack was fully cleared or the chat was opened.
  /// Used with [lastChatOpenedAt] to restore unread alerts after app restart.
  /// Individual swipe-dismissals are tracked separately so older cards remain.
  final DateTime? lastMessageAlertClearedAt;

  // ── File attachment (selected but not yet sent) ────────────────────────────
  final bool isFileSelected;
  final String? selectedFileName;
  final int? selectedFileSize;
  final String? pendingFileBase64;
  final String? pendingFileMime;

  const ChatState({
    this.currentTab = ChatTab.home,
    this.isChatOpen = false,
    this.isNewChat = false,
    this.sessionId = '',
    this.messages = const [],
    this.isTyping = false,
    this.isSending = false,
    this.isLoading = false,
    this.unreadCount = 0,
    this.error,
    this.pendingMessageAlerts = const [],
    this.lastChatOpenedAt,
    this.lastMessageAlertClearedAt,
    this.isFileSelected = false,
    this.selectedFileName,
    this.selectedFileSize,
    this.pendingFileBase64,
    this.pendingFileMime,
  });

  ChatState copyWith({
    ChatTab? currentTab,
    bool? isChatOpen,
    bool? isNewChat,
    String? sessionId,
    List<MessageModel>? messages,
    bool? isTyping,
    bool? isSending,
    bool? isLoading,
    int? unreadCount,
    // Pass null explicitly via the nullable wrapper trick:
    Object? error = _sentinel,
    List<MessageModel>? pendingMessageAlerts,
    Object? lastChatOpenedAt = _sentinel,
    Object? lastMessageAlertClearedAt = _sentinel,
    bool? isFileSelected,
    Object? selectedFileName = _sentinel,
    Object? selectedFileSize = _sentinel,
    Object? pendingFileBase64 = _sentinel,
    Object? pendingFileMime = _sentinel,
  }) =>
      ChatState(
        currentTab: currentTab ?? this.currentTab,
        isChatOpen: isChatOpen ?? this.isChatOpen,
        isNewChat: isNewChat ?? this.isNewChat,
        sessionId: sessionId ?? this.sessionId,
        messages: messages ?? this.messages,
        isTyping: isTyping ?? this.isTyping,
        isSending: isSending ?? this.isSending,
        isLoading: isLoading ?? this.isLoading,
        unreadCount: unreadCount ?? this.unreadCount,
        error: error == _sentinel ? this.error : error as String?,
        pendingMessageAlerts: pendingMessageAlerts ?? this.pendingMessageAlerts,
        lastChatOpenedAt: lastChatOpenedAt == _sentinel
            ? this.lastChatOpenedAt
            : lastChatOpenedAt as DateTime?,
        lastMessageAlertClearedAt: lastMessageAlertClearedAt == _sentinel
            ? this.lastMessageAlertClearedAt
            : lastMessageAlertClearedAt as DateTime?,
        isFileSelected: isFileSelected ?? this.isFileSelected,
        selectedFileName: selectedFileName == _sentinel
            ? this.selectedFileName
            : selectedFileName as String?,
        selectedFileSize: selectedFileSize == _sentinel
            ? this.selectedFileSize
            : selectedFileSize as int?,
        pendingFileBase64: pendingFileBase64 == _sentinel
            ? this.pendingFileBase64
            : pendingFileBase64 as String?,
        pendingFileMime: pendingFileMime == _sentinel
            ? this.pendingFileMime
            : pendingFileMime as String?,
      );

  @override
  List<Object?> get props => [
        currentTab,
        isChatOpen,
        isNewChat,
        sessionId,
        messages,
        isTyping,
        isSending,
        isLoading,
        unreadCount,
        error,
        pendingMessageAlerts,
        lastChatOpenedAt,
        lastMessageAlertClearedAt,
        isFileSelected,
        selectedFileName,
        selectedFileSize,
        pendingFileBase64,
        pendingFileMime,
      ];
}

/// Sentinel used so [copyWith] can distinguish "not passed" from explicit null.
const _sentinel = Object();
