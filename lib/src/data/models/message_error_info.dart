import 'package:equatable/equatable.dart';

/// Technical host-app API error details attached to an outbound chat message.
///
/// Sent under `messageData['error-info']` on the socket. Never shown in the
/// customer-facing composer text.
class MessageErrorInfo extends Equatable {
  /// Failing request URL (hidden from the user).
  final String? url;

  /// Structured details (method, status, message, source, timestamp, …).
  final Map<String, dynamic>? data;

  const MessageErrorInfo({
    this.url,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'data': data,
      };

  @override
  List<Object?> get props => [url, data];
}
