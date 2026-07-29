import 'package:equatable/equatable.dart';

/// Technical host-app API error details attached to an outbound chat message.
///
/// Sent under `messageData['error-info']` on the socket. Never shown in the
/// customer-facing composer text.
///
/// [data.message] should be the full API error body / object when available
/// (parsed JSON Map/List, or raw string) — not only an HTTP reason phrase.
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
