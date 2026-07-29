import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'message_send_status.dart';

/// Discriminates the intent of a [MessageModel].
/// Names are UPPERCASE to mirror the server-side `message_type` field values.
// ignore: constant_identifier_names
enum MessageType {
  // ignore: constant_identifier_names
  QUERY,
  // ignore: constant_identifier_names
  REPLY,
  // ignore: constant_identifier_names
  CALL;

  static MessageType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'QUERY':
        return MessageType.QUERY;
      case 'REPLY':
        return MessageType.REPLY;
      case 'CALL':
        return MessageType.CALL;
      default:
        return MessageType.QUERY;
    }
  }

  String get value => name;
}

/// A single message exchanged in a Covaone support conversation.
class MessageModel extends Equatable {
  final String messageId;
  final String message;
  final MessageType messageType;

  /// `"HUMAN"` for agent messages, `"backend"` for system messages.
  final String authorType;

  /// `"frontend"` (sent by customer) or `"backend"` (sent by agent/system).
  final String origin;

  final bool hasAttachment;
  final String? fileUrl;
  final DateTime timeCreated;

  /// Local delivery status for outbound messages. Server history defaults to [sent].
  final MessageSendStatus sendStatus;

  const MessageModel({
    required this.messageId,
    required this.message,
    required this.messageType,
    required this.authorType,
    required this.origin,
    required this.hasAttachment,
    this.fileUrl,
    required this.timeCreated,
    this.sendStatus = MessageSendStatus.sent,
  });

  /// Returns true when [fileUrl] points to a common image format.
  bool get isImage {
    if (fileUrl == null || fileUrl!.isEmpty) return false;
    final normalised = fileUrl!.toLowerCase().split('?').first;
    return normalised.endsWith('.jpg') ||
        normalised.endsWith('.jpeg') ||
        normalised.endsWith('.png') ||
        normalised.endsWith('.gif');
  }

  bool get isFromCustomer => origin == 'frontend';

  /// Returns true when this message carries a call-log payload.
  /// Mirrors JS: messageType==CALL, OR the message body is a JSON object with
  /// `call_id` AND at least one of `summary` / `direction` / `end_reason`.
  bool get isCallLog {
    if (messageType == MessageType.CALL) return true;
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, dynamic> && decoded.containsKey('call_id')) {
        return decoded.containsKey('summary') ||
            decoded.containsKey('direction') ||
            decoded.containsKey('end_reason');
      }
    } catch (_) {}
    return false;
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      // Prefer server ids; fall back to the client id so room echoes of our own
      // sends can be correlated with the optimistic bubble.
      messageId: json['_id'] as String? ??
          json['message_id'] as String? ??
          json['client_message_id'] as String? ??
          json['clientMessageId'] as String? ??
          const Uuid().v4(),
      message: json['message'] as String? ?? '',
      messageType: MessageType.fromString(json['message_type'] as String?),
      authorType: json['author_type'] as String? ?? 'backend',
      origin: json['origin'] as String? ??
          ((json['message_type'] as String?)?.toUpperCase() == 'QUERY'
              ? 'frontend'
              : 'backend'),
      hasAttachment: json['has_attachment'] as bool? ?? false,
      fileUrl: json['file_url'] as String?,
      timeCreated: _parseDateTime(json['time_created']),
      // Server payloads omit this; treat history as successfully delivered.
      sendStatus: MessageSendStatus.fromString(json['send_status'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': messageId,
        'message': message,
        'message_type': messageType.value,
        'author_type': authorType,
        'origin': origin,
        'has_attachment': hasAttachment,
        'file_url': fileUrl,
        'time_created': timeCreated.toIso8601String(),
        'send_status': sendStatus.value,
      };

  /// Constructs an optimistic customer message before the server ACK arrives.
  factory MessageModel.optimistic({
    required String text,
    required String sessionId,
  }) {
    return MessageModel(
      messageId: const Uuid().v4(),
      message: text,
      messageType: MessageType.QUERY,
      authorType: 'HUMAN',
      origin: 'frontend',
      hasAttachment: false,
      timeCreated: DateTime.now(),
      sendStatus: MessageSendStatus.pending,
    );
  }

  MessageModel copyWith({
    String? messageId,
    String? message,
    MessageType? messageType,
    String? authorType,
    String? origin,
    bool? hasAttachment,
    String? fileUrl,
    DateTime? timeCreated,
    MessageSendStatus? sendStatus,
  }) =>
      MessageModel(
        messageId: messageId ?? this.messageId,
        message: message ?? this.message,
        messageType: messageType ?? this.messageType,
        authorType: authorType ?? this.authorType,
        origin: origin ?? this.origin,
        hasAttachment: hasAttachment ?? this.hasAttachment,
        fileUrl: fileUrl ?? this.fileUrl,
        timeCreated: timeCreated ?? this.timeCreated,
        sendStatus: sendStatus ?? this.sendStatus,
      );

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  List<Object?> get props => [
        messageId,
        message,
        messageType,
        authorType,
        origin,
        hasAttachment,
        fileUrl,
        timeCreated,
        sendStatus,
      ];
}
