import 'package:equatable/equatable.dart';
import 'configuration_model.dart';
import 'message_model.dart';

/// Full session as returned by `POST /get-single-session`.
class SessionModel extends Equatable {
  final String sessionId;
  final String? email;
  final String? name;

  /// `"active"` / `"open"` when live, `"closed"` when ended.
  final String status;

  final List<MessageModel> messages;
  final ConfigurationModel configuration;

  const SessionModel({
    required this.sessionId,
    this.email,
    this.name,
    required this.status,
    required this.messages,
    required this.configuration,
  });

  /// Returns true when the session has a registered email address.
  bool get hasProfile =>
      email != null && email!.trim().isNotEmpty;

  bool get isOpen => status == 'open' || status == 'active';

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final rawMessages = (json['messages'] as List<dynamic>?) ?? [];
    final rawConfig = json['configuration'];

    return SessionModel(
      sessionId: json['session_id'] as String? ?? '',
      email: json['email'] as String?,
      name: json['name'] as String?,
      status: json['status'] as String? ?? 'open',
      messages: rawMessages
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      configuration: rawConfig != null
          ? ConfigurationModel.fromJson(rawConfig as Map<String, dynamic>)
          : const ConfigurationModel(
              supportName: '',
              color: '#592C83',
              contactEmail: '',
            ),
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'email': email,
        'name': name,
        'status': status,
        'messages': messages.map((m) => m.toJson()).toList(),
        'configuration': configuration.toJson(),
      };

  SessionModel copyWith({
    String? sessionId,
    String? email,
    String? name,
    String? status,
    List<MessageModel>? messages,
    ConfigurationModel? configuration,
  }) =>
      SessionModel(
        sessionId: sessionId ?? this.sessionId,
        email: email ?? this.email,
        name: name ?? this.name,
        status: status ?? this.status,
        messages: messages ?? this.messages,
        configuration: configuration ?? this.configuration,
      );

  @override
  List<Object?> get props =>
      [sessionId, email, name, status, messages, configuration];
}
