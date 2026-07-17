part of 'session_bloc.dart';

abstract class SessionEvent extends Equatable {
  const SessionEvent();
  @override
  List<Object?> get props => [];
}

/// Entry-point: called from [CovaoneChat.init]. Checks storage for an existing
/// session ID and routes to [CreateSessionEvent] or [GetSessionEvent].
class CovaoneInitializeEvent extends SessionEvent {
  final String publicKey;
  const CovaoneInitializeEvent({required this.publicKey});
  @override
  List<Object?> get props => [publicKey];
}

/// Creates a brand-new session via `POST /initiate-session`.
class CreateSessionEvent extends SessionEvent {
  final String publicKey;
  const CreateSessionEvent({required this.publicKey});
  @override
  List<Object?> get props => [publicKey];
}

/// Fetches the full session from `POST /get-single-session`.
class GetSessionEvent extends SessionEvent {
  final String sessionId;
  const GetSessionEvent({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}

/// Calls `POST /set-profile`, persists email, re-fetches session, then
/// connects the socket.
class SetProfileEvent extends SessionEvent {
  final String email;
  final String name;
  const SetProfileEvent({required this.email, required this.name});
  @override
  List<Object?> get props => [email, name];
}

/// Clears the persisted session and starts a fresh one.
class NewConversationEvent extends SessionEvent {
  const NewConversationEvent();
}

/// Refreshes the active session from the network only when the cached copy is
/// older than [CovaoneConfig.sessionCacheTtl].
class RefreshSessionIfStaleEvent extends SessionEvent {
  const RefreshSessionIfStaleEvent();
}

/// Pushes the latest in-memory message list into the loaded session so the
/// Conversations tab (and any other SessionBloc consumers) stay in sync with
/// ChatBloc / WebSocket updates without waiting for a network refresh.
class UpdateSessionMessagesEvent extends SessionEvent {
  final List<MessageModel> messages;
  const UpdateSessionMessagesEvent({required this.messages});
  @override
  List<Object?> get props => [messages];
}
