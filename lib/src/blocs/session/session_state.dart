part of 'session_bloc.dart';

/// Default fallback colour used before configuration is received.
const Color _kDefaultThemeColor = Color(0xFF592C83);

abstract class SessionState extends Equatable {
  const SessionState();

  /// The brand colour from the server configuration.
  /// Falls back to [_kDefaultThemeColor] for states that have no configuration yet.
  Color get themeColor => _kDefaultThemeColor;

  @override
  List<Object?> get props => [];
}

class SessionInitial extends SessionState {
  const SessionInitial();
}

class SessionLoading extends SessionState {
  const SessionLoading();
}

/// The session is fully loaded and the socket is connected (when profile exists).
class SessionLoaded extends SessionState {
  final SessionModel session;

  /// Two-letter uppercase initials derived from [ConfigurationModel.supportName].
  final String initials;

  /// Parsed brand colour from [ConfigurationModel.color].
  @override
  final Color themeColor;

  const SessionLoaded({
    required this.session,
    required this.initials,
    required this.themeColor,
  });

  @override
  List<Object?> get props => [session, initials, themeColor];
}

/// The user has not yet set their email — the profile form must be shown.
class SessionProfileFormVisible extends SessionState {
  /// Carry the session so the UI can still read configuration / theme.
  final SessionModel session;

  /// Parsed brand colour — available immediately from the initiate response.
  @override
  final Color themeColor;

  /// Non-null after a failed [SetProfileEvent]; cleared on the next attempt.
  final String? profileError;

  const SessionProfileFormVisible({
    required this.session,
    required this.themeColor,
    this.profileError,
  });

  @override
  List<Object?> get props => [session, themeColor, profileError];
}

/// Profile registration is in progress (manual submit or host-provided identity).
class SessionSettingProfile extends SessionState {
  final SessionModel session;

  @override
  final Color themeColor;

  const SessionSettingProfile({
    required this.session,
    required this.themeColor,
  });

  @override
  List<Object?> get props => [session, themeColor];
}

class SessionError extends SessionState {
  final String message;
  const SessionError({required this.message});
  @override
  List<Object?> get props => [message];
}
